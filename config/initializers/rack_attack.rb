# Basic abuse protection for auth endpoints (OTP + logins).
# Focused throttles only — no broad IP throttle, to avoid false-positives on
# the customer app's polling. Uses a shared Redis store across puma workers.
return unless defined?(Rack::Attack)

class Rack::Attack
  begin
    self.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      namespace: "rack_attack", error_handler: ->(*) {}
    )
  rescue StandardError => e
    Rails.logger.warn("[RackAttack] Redis store unavailable, using memory: #{e.class}")
  end

  safelist("localhost") { |req| %w[127.0.0.1 ::1].include?(req.ip) }

  # Cổng phụ huynh: xin mã OTP. Đường dẫn là "/vao" (không phải "/login" — chỗ
  # đó là đăng nhập của nhân sự), và định danh là SỐ ĐIỆN THOẠI.
  #
  # Bản cũ bê nguyên từ app khác: nó khoá theo `params["email"]` trên một form
  # chỉ gửi `phone`, nên khoá luôn rỗng và luật chưa bao giờ khớp lần nào. Mỗi
  # lần xin mã là một tin nhắn có tính tiền, nên một số điện thoại có thể bị dội
  # mã vô hạn miễn là đổi IP.
  otp_request = ->(req) { req.post? && req.path.end_with?("/vao") }

  throttle("otp/phone", limit: 5, period: 10.minutes) do |req|
    if otp_request.call(req)
      phone = req.params["phone"].to_s.gsub(/\D/, "")
      "otp-phone:#{phone}" if phone.present?
    end
  end
  throttle("otp/ip", limit: 20, period: 10.minutes) { |req| req.ip if otp_request.call(req) }

  # Nhập mã OTP: chặn dò mã theo IP (model đã chặn theo từng lượt phát mã).
  throttle("otp-verify/ip", limit: 30, period: 10.minutes) do |req|
    req.ip if req.post? && req.path.end_with?("/verify")
  end

  # Đăng nhập bằng mật khẩu của nhân sự và của Super Admin.
  #
  # Bản cũ nhắm vào "/merchant/login" — đường dẫn không tồn tại ở app này; đăng
  # nhập nhân sự nằm ở "/login". Nghĩa là luật dành riêng cho việc dò mật khẩu
  # chưa bao giờ chạy; nó chỉ tình cờ được luật OTP đỡ hộ, mà sửa luật OTP là
  # mất luôn cả phần đỡ đó.
  staff_login = ->(req) { req.post? && %w[/login /admin/login].include?(req.path) }

  throttle("login/ip", limit: 15, period: 20.minutes) { |req| req.ip if staff_login.call(req) }
  throttle("login/email", limit: 10, period: 20.minutes) do |req|
    if staff_login.call(req)
      email = (req.params.dig("user", "email") || req.params.dig("admin_user", "email")).to_s.strip.downcase
      "login-email:#{email}" if email.present?
    end
  end

  # Quét khuôn mặt: mỗi lượt là một lần suy luận InsightFace tốn 1-2 giây CPU
  # trên máy chủ 4 nhân dùng chung với puma và sidekiq. Cần đăng nhập mới gọi
  # được, nên đây là chặn tai nạn (kịch bản quét lặp, nút bấm liên tục) chứ
  # không phải chặn kẻ tấn công.
  throttle("face-scan/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.post? && req.path.end_with?("/scan/identify")
  end

  self.throttled_responder = lambda do |req|
    period = (req.env["rack.attack.match_data"] || {})[:period]
    [429, { "Content-Type" => "text/plain", "Retry-After" => period.to_s },
     ["Quá nhiều yêu cầu. Vui lòng thử lại sau ít phút. / Too many requests. Please try again shortly."]]
  end
end
