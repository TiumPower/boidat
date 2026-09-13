module Desk
  # Trang chính của quầy: danh sách đã điểm danh trong ca + nút quét lớn
  # (UX quầy điểm danh, màn 6 — cố tình không có menu).
  class AttendanceController < BaseController
    def index
      @today = Date.current
      @pool = current_pool
      @counts = { checked_in: 0, failed: 0, day_pass: 0 } # nối vào P3
      @entries = [] # Attendance của ca hôm nay — P3
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
