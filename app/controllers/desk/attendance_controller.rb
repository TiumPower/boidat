module Desk
  # Trang chính của quầy: danh sách ca trực + nút quét lớn (UX màn 6 — cố tình
  # không có menu, lễ tân đứng quầy chỉ cần một nút).
  class AttendanceController < BaseController
    def index
      @today = Date.current
      @entries = Attendance.where(pool_id: current_pool.id, checked_in_at: Time.current.all_day)
                           .includes(:student, lesson: :swim_class)
                           .order(checked_in_at: :desc).to_a
      @tickets = DayPassTicket.where(pool_id: current_pool.id).today.where.not(used_at: nil)
                              .order(used_at: :desc).to_a
      @counts = {
        checked_in: @entries.count { |a| a.status == "present" },
        failed: @entries.count { |a| a.status == "rejected" },
        day_pass: @tickets.sum(&:quantity)
      }
      @pending_lessons = Lesson.where(pool_id: current_pool.id, date: @today, status: "scheduled")
                               .includes(swim_class: { enrollments: :student }).order(:start_hour).to_a
    end

    def select_pool
      if switch_pool!(params[:pool_id])
        redirect_to desk_root_path, notice: "Đang trực tại #{current_pool.name}."
      else
        redirect_to desk_root_path, alert: "Bạn không được gán vào hồ này."
      end
    end

    private

    def nav_key = :attendance
  end
end
