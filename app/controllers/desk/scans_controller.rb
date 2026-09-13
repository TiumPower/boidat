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
