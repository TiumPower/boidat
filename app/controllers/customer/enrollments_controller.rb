module Customer
  # Phụ huynh / học viên CŨ tự đăng ký khoá mới ngay trên PWA.
  #
  # Chỉ mở cho hộ đã có học viên: họ đã ký cam kết, đã có hồ trực thuộc, đã có
  # hồ sơ — không còn gì để sale phải nhập hộ. Bắt họ gọi điện để tái ký chỉ tạo
  # thêm ma sát ở đúng lúc họ đang muốn mua tiếp.
  #
  # Học viên MỚI vẫn phải qua sale (FR-204): cần thu thập thông tin, chọn hồ, ký
  # cam kết lần đầu.
  class EnrollmentsController < BaseController
    before_action :require_guardian!
    before_action :require_payment_access!   # tái ký là phát sinh tiền → chỉ chủ hộ
    before_action :set_student

    def new
      @options = SelfEnrollmentOptions.new(pool: @student.pool, student: @student)
      @history = @student.enrollments.includes(swim_class: [:teacher, :course]).order(created_at: :desc).to_a
    end

    def create
      form = build_form
      result = RegisterStudent.new(form: form, workspace: current_workspace,
                                   pool: @student.pool, actor: nil).call
      if result.ok?
        notify_staff(result)
        redirect_to member_order_path(id: result.order.id),
                    notice: "Đã đăng ký khoá mới cho #{@student.short_name}. " \
                            "Thanh toán để trung tâm xếp lịch chính thức."
      else
        @options = SelfEnrollmentOptions.new(pool: @student.pool, student: @student)
        @history = @student.enrollments.order(created_at: :desc).to_a
        @error = result.errors.uniq.join(" · ")
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_student
      @student = household_students.find(params[:student_id])
    end

    def build_form
      attrs = {
        student_id: @student.id,
        household_id: @student.household_id,
        package_id: params[:package_id],
        customer_type: "returning"
      }

      if params[:swim_class_id].present?
        attrs[:swim_class_id] = params[:swim_class_id]
      else
        teacher_id, weekday, hour = params[:slot].to_s.split(":")
        # Không truyền class_type: loại lớp lấy theo GÓI khách đã chọn, để không
        # có chuyện trả tiền gói 1:1 mà bị mở lớp 1:2.
        attrs.merge!(
          teacher_id: teacher_id, start_hour: hour, weekday_list: weekday,
          start_date: SelfEnrollmentOptions.new(pool: @student.pool).suggested_start(weekday.to_i)
        )
      end

      form = RegistrationForm.new(attrs)
      form.workspace = current_workspace
      form.pool = @student.pool
      form
    end

    # Tái ký là doanh thu — admin của hồ phải biết ngay, không đợi tới lúc đối soát.
    def notify_staff(result)
      staff_ids = User.where(id: PoolAssignment.where(pool_id: @student.pool_id).select(:user_id))
                      .where(id: Membership.where(workspace_id: current_workspace.id,
                                                  role: %w[bod admin sale]).select(:user_id))
                      .pluck(:id)
      return if staff_ids.empty?

      title = "#{@student.name} tự đăng ký khoá mới"
      body = "#{result.swim_class.slot_label} · #{result.swim_class.teacher.display_name} · " \
             "đơn #{result.order.code} chờ thanh toán"
      staff_ids.each do |uid|
        Notification.create!(workspace: current_workspace, recipient_type: "User", recipient_id: uid,
                             kind: "class_created", title: title, body: body,
                             subject: result.enrollment,
                             deep_link: "/merchant/ops/orders/#{result.order.id}")
      end
      PushJob.perform_later(current_workspace.id, "User", staff_ids, title, body,
                            "/merchant/ops/orders/#{result.order.id}")
    end
  end
end
