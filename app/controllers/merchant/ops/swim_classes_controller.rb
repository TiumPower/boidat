module Merchant
  module Ops
    # Chi tiết một lớp: danh sách học viên, tiến độ buổi, và các buổi đã/sẽ diễn ra.
    class SwimClassesController < BaseController
      before_action :set_class

      def show
        @enrollments = @swim_class.enrollments.includes(:student, :package).to_a
        @lessons = @swim_class.lessons.order(:session_index).includes(attendances: :student).to_a
      end

      def edit
        @teachers = ::Teacher.staff.active.in_pool(current_pool).includes(:user).to_a
      end

      # Đổi giáo viên / khung giờ chỉ áp cho các buổi CHƯA diễn ra — lịch sử điểm
      # danh và chấm công của buổi đã học không được phép thay đổi.
      def update
        weekdays = params[:weekdays].present? ? Array(params[:weekdays]).map(&:to_i) : nil
        LessonGenerator.new(@swim_class).reschedule_future!(
          weekdays: weekdays,
          start_hour: params[:start_hour].presence&.to_i,
          teacher: params[:teacher_id].present? ? ::Teacher.find(params[:teacher_id]) : nil
        )
        audit!("update", @swim_class, summary: "Đổi lịch lớp #{@swim_class.code}")
        redirect_to merchant_ops_class_path(@swim_class), notice: "Đã dời các buổi chưa diễn ra."
      end

      private

      def nav_key = :schedule
      def set_class = @swim_class = SwimClass.where(pool_id: current_pool.id).find(params[:id])
    end
  end
end
