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
      # Danh sách DỰ KIẾN của ca trực, không phải nhật ký: lễ tân cần trả lời
      # "em này hôm nay có lịch không" và "còn ai chưa tới". Lấy cả buổi đã có
      # người điểm danh (status "done") để danh sách không rụng dần trong ca.
      @pending_lessons = Lesson.where(pool_id: current_pool.id, date: @today)
                               .where.not(status: "cancelled")
                               .includes(:teacher, swim_class: { enrollments: :student })
                               .order(:start_hour).to_a
      @checked_in_ids = @entries.select { |a| a.status == "present" }.map(&:student_id).to_set
      @expected_count = @pending_lessons.sum { |l| l.swim_class.active_enrollments.size }
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
