module Customer
  # Xin vắng & đặt lại buổi khác (FR-404). Cùng một màn hình dùng cho hai lối
  # vào: phụ huynh bấm từ thông báo "thầy nghỉ", hoặc chủ động xin vắng.
  class MakeupsController < BaseController
    before_action :require_guardian!

    def index
      @pending = MakeupRequest.pending.where(student_id: household_students.select(:id))
                              .includes(:student, from_lesson: :teacher).recent.to_a
      @booked = MakeupRequest.where(student_id: household_students.select(:id), status: "booked")
                             .includes(:student, to_lesson: :teacher).recent.limit(10).to_a
      @upcoming = upcoming_lessons
    end

    def show
      @request = find_request
      @options = MakeupOptions.new(enrollment: @request.enrollment,
                                   from_lesson: @request.from_lesson).call
    end

    # Phụ huynh chủ động xin vắng một buổi sắp tới.
    def create
      lesson = Lesson.where(pool_id: household_pool_ids, status: "scheduled").find(params[:lesson_id])
      enrollment = Enrollment.active.find_by(swim_class_id: lesson.swim_class_id,
                                             student_id: household_students.select(:id))
      return redirect_to(member_makeups_path, alert: "Không tìm thấy đăng ký cho buổi này.") if enrollment.nil?

      request = MakeupRequest.find_or_create_by!(workspace: current_workspace, enrollment: enrollment,
                                                 from_lesson: lesson) do |m|
        m.pool = lesson.pool
        m.student = enrollment.student
        m.origin = "guardian_absence"
        m.reason = params[:reason]
        m.status = "pending"
      end
      redirect_to member_makeup_path(id: request.id), notice: "Đã ghi nhận. Hãy chọn buổi học bù."
    end

    def book
      request = find_request
      if params[:choice] == "follow_teacher"
        # "Nghỉ theo thầy" — chờ trung tâm sắp lịch bù với chính giáo viên đó.
        request.update!(choice: "follow_teacher", status: "booked",
                        decided_by: current_guardian, decided_at: Time.current)
        return redirect_to member_makeups_path,
                           notice: "Đã ghi nhận: nghỉ theo thầy. Trung tâm sẽ báo lịch bù."
      end

      lesson = Lesson.where(pool_id: household_pool_ids).find(params[:lesson_id])
      if lesson.swim_class.full?
        return redirect_to member_makeup_path(id: request.id), alert: "Buổi này vừa hết chỗ. Chọn buổi khác giúp em."
      end

      choice = lesson.teacher_id == request.enrollment.swim_class.teacher_id ? "other_slot" : "other_teacher"
      request.book!(lesson: lesson, choice: choice, guardian: current_guardian)
      notify_staff(request)
      redirect_to member_makeups_path,
                  notice: "Đã đặt buổi bù #{l(lesson.date, format: '%d/%m')} lúc #{lesson.time_label}."
    end

    private

    def find_request
      MakeupRequest.where(student_id: household_students.select(:id)).find(params[:id])
    end

    def household_pool_ids = household_students.select(:pool_id)

    def upcoming_lessons
      class_ids = Enrollment.active.where(student_id: household_students.select(:id)).pluck(:swim_class_id)
      return [] if class_ids.empty?
      Lesson.where(swim_class_id: class_ids, status: "scheduled")
            .where(date: Date.current..(Date.current + 30))
            .includes(:teacher, swim_class: :course).order(:date, :start_hour).limit(10).to_a
    end

    def notify_staff(request)
      staff = User.where(id: PoolAssignment.where(pool_id: request.pool_id).select(:user_id))
      return if staff.empty?
      title = "#{request.student.name} đã chọn buổi bù"
      body = "#{request.choice_label} · #{I18n.l(request.to_lesson.date, format: '%d/%m')} #{request.to_lesson.time_label}"
      staff.each do |u|
        Notification.create!(workspace: current_workspace, recipient: u, kind: "teacher_leave",
                             title: title, body: body, subject: request,
                             deep_link: "/merchant/ops/leave-requests")
      end
    end
  end
end
