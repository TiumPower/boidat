module Coach
  # Chi tiết buổi dạy + sửa giáo án cho riêng buổi này + ghi nhận xét (FR-302/303).
  class LessonsController < BaseController
    before_action :set_lesson

    def show
      @swim_class = @lesson.swim_class
      @enrollments = @swim_class.enrollments.active.includes(:student).to_a
      @attendances = @lesson.attendances.index_by(&:student_id)
      @feedbacks = @lesson.session_feedbacks.index_by(&:student_id)
      @entry = @lesson.timesheet_entry
    end

    # Sửa nội dung buổi dạy — chỉ áp cho buổi này, không đụng giáo án gốc của khoá.
    def update
      @lesson.update!(content_override: params[:content_override])
      redirect_to teacher_lesson_path(@lesson), notice: "Đã lưu nội dung buổi dạy."
    end

    private

    def nav_key = :schedule

    def set_lesson
      @lesson = Lesson.where(teacher_id: current_teacher.id).find(params[:id])
    end
  end
end
