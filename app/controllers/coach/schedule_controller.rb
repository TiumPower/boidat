module Coach
  # Lịch dạy của tôi (FR-302). P0 dựng khung + khung giờ đã đăng ký;
  # lớp, học viên, giáo án và nhận xét nối vào ở P3.
  class ScheduleController < BaseController
    def index
      @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
      @teacher = current_teacher
      @lessons = [] # P3
      @summary = { lessons: 0, credits: 0.0, pending_feedback: 0 }
    rescue ArgumentError
      redirect_to teacher_root_path
    end

    private

    def nav_key = :schedule
  end
end
