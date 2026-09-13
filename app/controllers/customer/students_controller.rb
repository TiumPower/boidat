module Customer
  # Tiến độ học và nhận xét của giáo viên (FR-406) — thứ phụ huynh mở nhiều nhất.
  class StudentsController < BaseController
    before_action :require_guardian!

    def show
      @student = household_students.find(params[:id])
      @enrollment = @student.enrollments.includes(swim_class: [:teacher, :course]).order(created_at: :desc).first
      @feedbacks = SessionFeedback.where(student_id: @student.id).includes(:lesson, :teacher)
                                  .order(created_at: :desc).limit(20).to_a
      @upcoming = upcoming_lessons
    end

    private

    def upcoming_lessons
      class_ids = @student.enrollments.active.pluck(:swim_class_id)
      return [] if class_ids.empty?
      Lesson.where(swim_class_id: class_ids, status: "scheduled")
            .where("date >= ?", Date.current)
            .includes(:teacher).order(:date, :start_hour).limit(6).to_a
    end
  end
end
