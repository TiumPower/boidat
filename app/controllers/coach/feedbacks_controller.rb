module Coach
  # Nhận xét sau buổi học cho TỪNG học viên (FR-303).
  #
  # Công KHÔNG chờ nhận xét (OQ-22, cấu hình được): gộp hai nghiệp vụ không liên
  # quan sẽ thành tranh chấp lương khi thầy quên nhận xét. Nhận xét là nghĩa vụ
  # riêng, có deadline và có nhắc.
  class FeedbacksController < BaseController
    before_action :set_lesson

    def new
      @swim_class = @lesson.swim_class
      @enrollments = @swim_class.enrollments.active.includes(:student).to_a
      @attendances = @lesson.attendances.index_by(&:student_id)
      @feedbacks = @lesson.session_feedbacks.index_by(&:student_id)
    end

    def create
      saved = 0
      ActiveRecord::Base.transaction do
        (params[:feedbacks] || {}).each do |student_id, attrs|
          next if attrs[:body].blank? && attrs[:tag].blank?
          student = Student.find(student_id)
          fb = SessionFeedback.find_or_initialize_by(workspace: current_workspace, lesson: @lesson,
                                                     student: student)
          fb.assign_attributes(pool: @lesson.pool, teacher: current_teacher,
                               tag: attrs[:tag], body: attrs[:body], sent_at: Time.current)
          fb.save!
          notify_guardians(fb)
          saved += 1
        end
      end
      # Nếu trung tâm bật tuỳ chọn "nhận xét mới tính công" thì đây là lúc công
      # được mở khoá — nên tính lại ngay.
      PayrollCalculator.new(@lesson.reload).call

      redirect_to teacher_lesson_path(@lesson), notice: "Đã gửi #{saved} nhận xét cho phụ huynh."
    end

    private

    def nav_key = :schedule
    def set_lesson = @lesson = Lesson.where(teacher_id: current_teacher.id).find(params[:lesson_id])

    def notify_guardians(feedback)
      guardians = feedback.student.household.guardians.to_a
      return if guardians.empty?
      title = "#{current_teacher.display_name} đã nhận xét buổi #{@lesson.session_index}"
      body = feedback.body.to_s.truncate(120)
      guardians.each do |g|
        Notification.create!(workspace: current_workspace, recipient: g, kind: "feedback",
                             title: title, body: body, subject: feedback,
                             deep_link: "/students/#{feedback.student_id}")
      end
      PushJob.perform_later(current_workspace.id, "Guardian", guardians.map(&:id), title, body,
                            "/students/#{feedback.student_id}")
    end
  end
end
