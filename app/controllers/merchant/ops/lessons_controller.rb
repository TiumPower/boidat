module Merchant
  module Ops
    # Chi tiết một buổi học + điểm danh thủ công.
    #
    # FR-234: khi nhận diện khuôn mặt thất bại, admin KHÔNG có màn hình tra cứu
    # riêng trên PWA — họ mở đúng slot này trên bảng master data và tích có mặt.
    # Mỗi lần sửa tay đều vào nhật ký để đối chiếu khi tranh chấp và để đo tỷ lệ
    # nhận diện lỗi.
    class LessonsController < BaseController
      before_action :set_lesson

      def show
        @swim_class = @lesson.swim_class
        @enrollments = @swim_class.enrollments.active.includes(:student).to_a
        @attendances = @lesson.attendances.index_by(&:student_id)
        render layout: false if turbo_frame_request?
      end

      def update
        @lesson.update!(content_override: params[:content_override])
        audit!("update", @lesson, summary: "Sửa nội dung buổi #{@lesson.session_index}")
        redirect_to merchant_ops_lesson_path(@lesson), notice: "Đã lưu nội dung buổi học."
      end

      # Tích / bỏ tích có mặt cho một học viên.
      def attend
        student = Student.find(params[:student_id])
        result = AttendanceRecorder.new(lesson: @lesson, student: student, actor: current_user,
                                        method: "manual").toggle!
        audit!("update", @lesson,
               summary: "Điểm danh tay #{student.name} · #{result[:status]} · buổi #{@lesson.session_index}")
        redirect_back fallback_location: merchant_ops_lesson_path(@lesson),
                      notice: result[:message]
      end

      private

      def nav_key = :schedule
      def set_lesson = @lesson = Lesson.where(pool_id: current_pool.id).find(params[:id])
    end
  end
end
