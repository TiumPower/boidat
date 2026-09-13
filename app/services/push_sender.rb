require "web_push"

# Gửi Web Push tới các PWA đã cài (phụ huynh, giáo viên, quầy điểm danh).
# No-op an toàn khi chưa cấu hình VAPID (giống PayosService#configured?).
module PushSender
  module_function

  def configured?
    ENV["VAPID_PUBLIC_KEY"].present? && ENV["VAPID_PRIVATE_KEY"].present?
  end

  def public_key = ENV["VAPID_PUBLIC_KEY"].to_s

  def vapid
    { subject:     ENV.fetch("VAPID_SUBJECT", "mailto:admin@boidat.czin.net"),
      public_key:  ENV["VAPID_PUBLIC_KEY"],
      private_key: ENV["VAPID_PRIVATE_KEY"] }
  end

  # recipient_type: "Guardian" | "User"
  def deliver_to(recipient_type, recipient_ids, title:, body:, path: "/", icon: nil)
    return unless configured? && recipient_ids.present?
    payload = JSON.generate(title: title, body: body.to_s, path: path, icon: icon)
    column = recipient_type.to_s == "Guardian" ? :guardian_id : :user_id
    # Nhân sự có thể thuộc nhiều workspace nên tra thiết bị của họ ngoài tenant scope.
    scope = -> { PushSubscription.where(column => recipient_ids).find_each { |s| send_one(s, payload) } }
    column == :user_id ? ActsAsTenant.without_tenant { scope.call } : scope.call
  end

  def deliver_to_guardians(ids, **kw) = deliver_to("Guardian", ids, **kw)
  def deliver_to_users(ids, **kw)     = deliver_to("User", ids, **kw)

  def send_one(sub, payload)
    WebPush.payload_send(message: payload, endpoint: sub.endpoint,
                         p256dh: sub.p256dh, auth: sub.auth, vapid: vapid, urgency: "normal")
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
    sub.destroy
  rescue => e
    Rails.logger.error("[PushSender] #{e.class}: #{e.message}")
  end
end
