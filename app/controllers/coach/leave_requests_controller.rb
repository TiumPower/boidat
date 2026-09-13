module Coach
  # Giáo viên gửi đơn xin nghỉ ngay trên PWA (FR-305). Admin duyệt ở P6.
  class LeaveRequestsController < BaseController
    def index
      @requests = LeaveRequest.where(teacher_id: current_teacher.id).recent.limit(20).to_a
    end

    def new
      @request = LeaveRequest.new
      @lessons = upcoming_lessons
    end

    def create
      lesson_ids = Array(params[:lesson_ids]).map(&:to_i)
      @request = LeaveRequest.new(workspace: current_workspace, teacher: current_teacher,
                                  reason: params[:reason], lesson_ids: lesson_ids,
                                  status: "pending", submitted_at: Time.current)
      if lesson_ids.empty?
        @request.errors.add(:base, "Chưa chọn buổi cần nghỉ")
        @lessons = upcoming_lessons
        return render(:new, status: :unprocessable_entity)
      end

      @request.save!
      notify_admins
      redirect_to teacher_leave_requests_path, notice: "Đã gửi đơn cho Admin duyệt."
    end

    private

    def nav_key = :leaves

    def upcoming_lessons
      Lesson.where(teacher_id: current_teacher.id, status: "scheduled")
            .where("date >= ?", Date.current)
            .includes(swim_class: { enrollments: :student })
            .order(:date, :start_hour).limit(30).to_a
    end

    def notify_admins
      admins = current_workspace.memberships.where(role: %w[bod admin]).includes(:user).map(&:user)
      return if admins.empty?
      title = "Đơn xin nghỉ từ #{current_teacher.display_name}"
      body = "#{@request.lesson_ids.size} buổi · #{@request.reason.to_s.truncate(80)}"
      admins.each do |u|
        Notification.create!(workspace: current_workspace, recipient: u, kind: "teacher_leave",
                             title: title, body: body, subject: @request,
                             deep_link: "/merchant/ops/leave-requests")
      end
      PushJob.perform_later(current_workspace.id, "User", admins.map(&:id), title, body,
                            "/merchant/ops/leave-requests")
    end
  end
end
