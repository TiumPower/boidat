# Người giám hộ / người đưa đón trong một hộ gia đình.
# `owner`  — chủ hộ: thấy tất cả, gồm lịch sử thanh toán.
# `pickup` — người đưa đón: chỉ thấy lịch học và điểm danh (OQ-03).
class Guardian < ApplicationRecord
  acts_as_tenant(:workspace)

  ROLES = %w[owner pickup].freeze
  ROLE_LABELS = { "owner" => "Chủ gia đình", "pickup" => "Người đưa đón" }.freeze

  belongs_to :workspace
  belongs_to :household
  has_many :students, dependent: :nullify   # chỉ set với người lớn tự học
  has_many :notifications, as: :recipient, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :qr_token, presence: true, uniqueness: true

  before_validation :ensure_qr_token, on: :create

  scope :owners, -> { where(role: "owner") }

  before_save :normalize_phone

  def owner?  = role == "owner"
  def pickup? = role == "pickup"
  def role_label = ROLE_LABELS[role]

  # Chủ hộ mới xem được tiền; cấu hình được qua BusinessSettings (OQ-03).
  def can_view_payments?
    return true unless workspace.payments_owner_only?
    owner?
  end

  # Mã QR là của TỪNG NGƯỜI, không phải của hộ. Trước đây cả hộ dùng chung một
  # mã và ai quét cũng đăng nhập thành chủ hộ — nghĩa là người đưa đón cầm đúng
  # mã ấy là xem được toàn bộ hoá đơn, làm OQ-03 mất hiệu lực. Mã riêng từng
  # người thì quét xong hệ thống biết đang nói chuyện với ai.
  def qr_active? = qr_revoked_at.nil?

  def reissue_qr!
    update!(qr_token: self.class.generate_token, qr_issued_at: Time.current, qr_revoked_at: nil)
  end

  def revoke_qr! = update!(qr_revoked_at: Time.current)

  def self.generate_token = SecureRandom.urlsafe_base64(18)

  def initials = name.to_s.split.map { |w| w[0] }.first(2).join.upcase

  def self.normalize_phone(value)
    digits = value.to_s.gsub(/\D/, "")
    digits = "0#{digits[2..]}" if digits.start_with?("84") && digits.length >= 11
    digits
  end

  private

  def normalize_phone
    self.phone = self.class.normalize_phone(phone) if phone.present?
  end

  def ensure_qr_token
    self.qr_token ||= self.class.generate_token
    self.qr_issued_at ||= Time.current
  end
end
