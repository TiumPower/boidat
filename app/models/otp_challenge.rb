# OTP dùng ở hai chỗ:
#   scope "staff"    — nhân sự quên mật khẩu, gửi qua email (workspace_id NULL).
#   scope "guardian" — học viên người lớn tự học đăng nhập bằng SĐT (UX phụ huynh, màn 1).
# Không tenant-scoped: lúc gửi mã còn chưa biết chắc workspace nào.
class OtpChallenge < ApplicationRecord
  TTL = 10.minutes
  MAX_ATTEMPTS = 5
  SCOPES = %w[staff guardian].freeze

  belongs_to :workspace, optional: true

  validates :identity, :code, presence: true
  validates :scope, inclusion: { in: SCOPES }

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def self.normalize(identity, scope)
    return Guardian.normalize_phone(identity) if scope.to_s == "guardian"
    identity.to_s.strip.downcase
  end

  def self.issue!(identity:, scope: "staff", workspace: nil, purpose: "login")
    code = format("%06d", SecureRandom.random_number(1_000_000))
    challenge = create!(identity: normalize(identity, scope), scope: scope,
                        workspace: workspace, purpose: purpose,
                        code: code, expires_at: TTL.from_now)
    if scope.to_s == "staff" && EmailOtp.configured?
      OtpMailer.login_code(challenge).deliver_later
      Rails.logger.info("[OTP] scope=#{scope} #{identity} (emailed)")
    else
      # Giai đoạn 1 không tích hợp SMS/Zalo (A5) — mã hiện thẳng trên màn hình
      # xác thực và ghi vào log để admin đọc cho phụ huynh qua điện thoại.
      Rails.logger.info("[OTP] scope=#{scope} #{identity} code=#{code} (on-screen)")
    end
    challenge
  end

  def self.latest_for(identity:, scope: "staff", workspace: nil)
    where(identity: normalize(identity, scope), scope: scope, workspace_id: workspace&.id)
      .order(created_at: :desc).first
  end

  def verify(input)
    return :expired if expires_at < Time.current || consumed_at.present?
    increment!(:attempts)
    return :too_many if attempts > MAX_ATTEMPTS
    return :mismatch unless ActiveSupport::SecurityUtils.secure_compare(code, input.to_s)
    update!(consumed_at: Time.current)
    :ok
  end

  # OtpMailer dùng chung với estate/loyalty nên vẫn hỏi `email`.
  def email = identity
end
