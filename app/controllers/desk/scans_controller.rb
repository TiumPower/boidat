module Desk
  # Quét khuôn mặt tại quầy (FR-231 → FR-235 → FR-233).
  #
  # Ở giai đoạn này service nhận diện (InsightFace/FastAPI) chưa gắn vào, nên
  # màn hình chạy hai đường: tra cứu theo tên (dự phòng, luôn dùng được) và quét
  # vé lẻ QR. Khi FaceClient sẵn sàng, chỉ cần thay bước "tìm học viên".
  class ScansController < BaseController
    def new
      @query = params[:q].to_s.strip
      @candidates = @query.length >= 2 ? lookup_students(@query) : []
      @match = params[:student_id].present? ? find_student(params[:student_id]) : nil
      @context = @match ? StudentCheckInContext.new(student: @match, pool: current_pool).call : nil
      @face_ready = FaceClient.new.healthy?
      @score = params[:score]
    end

    # Nhận ảnh từ camera của PWA và tra cứu bằng service nhận diện.
    #
    # Trả JSON để màn hình quét cập nhật tại chỗ, không nạp lại trang giữa lúc
    # camera đang mở. Service chết thì trả `fallback: true` để PWA chuyển sang
    # ô tra cứu theo tên — quầy không bao giờ được đứng vì service.
    def identify
      image = decode_image(params[:image])
      return render(json: { ok: false, error: "Ảnh không hợp lệ" }, status: :bad_request) if image.nil?

      client = FaceClient.new
      matches = client.search(workspace_id: current_workspace.id, image: image, top_k: 3)
      if matches.empty?
        record_scan_failure
        return render json: { ok: false, fallback: !client.healthy?,
                              error: "Không nhận ra khuôn mặt. Thử lại hoặc tra cứu theo tên." }
      end

      top = matches.first
      student = Student.find_by(id: top.student_id)
      return render(json: { ok: false, error: "Không tìm thấy hồ sơ học viên." }) if student.nil?

      student.face_profile&.record_scan!(success: top.score >= current_workspace.face_match_threshold)

      if top.score < current_workspace.face_match_threshold
        # Vùng xám: đủ giống để gợi ý nhưng chưa đủ chắc để tự điểm danh — bắt
        # lễ tân xác nhận bằng mắt thay vì trừ buổi của nhầm người.
        render json: { ok: true, needs_confirm: true, score: top.score,
                       redirect: desk_scan_path(student_id: student.id, score: top.score) }
      else
        render json: { ok: true, score: top.score,
                       redirect: desk_scan_path(student_id: student.id, score: top.score) }
      end
    end

    # Xác nhận điểm danh → trừ đúng 1 buổi (FR-233).
    def create
      student = find_student(params[:student_id])
      return redirect_to(desk_scan_path, alert: "Không tìm thấy học viên.") if student.nil?

      context = StudentCheckInContext.new(student: student, pool: current_pool).call
      unless context.allowed?
        record_rejection(student, context)
        return redirect_to desk_scan_path(student_id: student.id), alert: context.reason
      end

      result = AttendanceRecorder.new(lesson: context.lesson, student: student, actor: current_user,
                                      method: params[:method].presence || "manual",
                                      face_score: params[:face_score]).check_in!
      if result.ok?
        AuditLog.record!(action: "update", entity: result.attendance, user: current_user,
                         pool: current_pool, summary: "Điểm danh #{student.name} tại quầy", request: request)
        redirect_to desk_root_path, notice: result.message
      else
        redirect_to desk_scan_path(student_id: student.id), alert: result.message
      end
    end

    # Vé lẻ dùng mã QR một lần, không đăng ký khuôn mặt (OQ-13).
    def ticket
      code = params[:code].to_s.strip.upcase
      ticket = DayPassTicket.find_by(code: code)

      if ticket.nil?
        redirect_to desk_scan_path, alert: "Không tìm thấy vé #{code}."
      elsif ticket.pool_id != current_pool.id
        redirect_to desk_scan_path, alert: "Vé này thuộc #{ticket.pool.name}, không dùng ở đây được."
      elsif !ticket.usable?
        redirect_to desk_scan_path, alert: "Vé #{code} #{ticket.status_label.downcase}."
      else
        ticket.redeem!
        AuditLog.record!(action: "update", entity: ticket, user: current_user, pool: current_pool,
                         summary: "Dùng vé lẻ #{code}", request: request)
        redirect_to desk_root_path, notice: "Đã ghi nhận vé #{code} · #{ticket.quantity} lượt."
      end
    end

    private

    def nav_key = :attendance

    def decode_image(data_url)
      return nil if data_url.blank?
      encoded = data_url.include?(",") ? data_url.split(",", 2).last : data_url
      raw = Base64.decode64(encoded)
      raw.presence
    rescue StandardError
      nil
    end

    # Quét trượt cũng là dữ liệu: tỷ lệ trượt cao ở một hồ nghĩa là ánh sáng
    # quầy có vấn đề, còn cao ở một học viên nghĩa là ảnh của em đó đã cũ.
    def record_scan_failure
      AuditLog.record!(action: "read_sensitive", entity: current_pool, user: current_user,
                       pool: current_pool, summary: "Quét khuôn mặt không ra kết quả",
                       request: request)
    end

    # NGOẠI LỆ CÓ CHỦ ĐÍCH (FR-235): tra cứu chạy trên toàn bộ học viên của
    # trung tâm, KHÔNG lọc theo hồ đang trực — quét ở quầy nào cũng ra. Nhưng
    # kết quả chỉ mang thông tin định danh tối thiểu, và mọi thao tác GHI vẫn bị
    # chặn theo hồ ở StudentCheckInContext.
    def lookup_students(query)
      Student.where(status: "active").where("students.name ILIKE :q", q: "%#{query}%")
             .includes(:pool, :face_profile).limit(8).to_a
    end

    def find_student(id) = Student.find_by(id: id)

    # Ghi lại lượt bị từ chối để đo tỷ lệ quét sai hồ / sai lịch.
    def record_rejection(student, context)
      return if context.lesson.nil?
      Attendance.find_or_create_by!(workspace: current_workspace, pool: current_pool,
                                    lesson: context.lesson, student: student) do |a|
        a.status = "rejected"
        a.method = "face"
        a.actor = current_user
        a.note = context.reason
      end
    rescue ActiveRecord::RecordInvalid
      nil
    end
  end
end
