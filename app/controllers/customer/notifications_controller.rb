module Customer
  # Trung tâm thông báo (FR-405) + xác nhận phương án khi thầy nghỉ (OQ-16).
  #
  # Vì đã chốt bỏ Zalo ZNS/SMS, cơ chế là "phụ huynh xác nhận ngay trên PWA",
  # nên trạng thái xác nhận phải theo dõi được — admin có danh sách ai chưa xác
  # nhận để gọi điện.
  class NotificationsController < BaseController
    before_action :require_guardian!

    def index
      @notifications = Notification.where(recipient: current_guardian).recent.limit(60).to_a
      @pending = @notifications.select(&:awaiting_ack?)
    end

    def read_all
      Notification.where(recipient: current_guardian, read_at: nil).update_all(read_at: Time.current)
      redirect_to member_notifications_path, notice: "Đã đánh dấu tất cả là đã đọc."
    end

    def ack
      notification = Notification.where(recipient: current_guardian).find(params[:id])
      notification.acknowledge!(params[:choice])
      redirect_back fallback_location: member_notifications_path, notice: "Đã ghi nhận lựa chọn của bạn."
    end
  end
end
