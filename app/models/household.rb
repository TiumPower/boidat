# Hộ gia đình (FR-206) — đơn vị đăng nhập của cổng phụ huynh. Cả nhà dùng chung
# một mã QR; ai cầm QR đều vào được (OQ-02 khách đã chấp nhận rủi ro này), nhưng
# quyền xem lịch sử thanh toán còn phụ thuộc vai trò của người giám hộ (OQ-03).
class Household < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[family individual].freeze

  belongs_to :workspace
  has_many :guardians, dependent: :destroy
  has_many :students,  dependent: :restrict_with_error

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :qr_token, presence: true, uniqueness: true

  before_validation :ensure_qr_token, on: :create

  scope :families, -> { where(kind: "family") }

  # Người lớn tự học: hộ chỉ có một người, vừa là học viên vừa là chủ hộ.
  def individual? = kind == "individual"
  def family?     = kind == "family"

  def owner = guardians.find_by(role: "owner") || guardians.first

  def qr_active? = qr_revoked_at.nil?

  # Thu hồi và cấp lại mã QR (OQ-02): phụ huynh mất điện thoại, đổi số, hoặc
  # gia đình nghỉ rồi quay lại. Không có nút này thì mã đã cấp là không rút được.
  def reissue_qr!
    update!(qr_token: self.class.generate_token, qr_issued_at: Time.current, qr_revoked_at: nil)
  end

  def revoke_qr! = update!(qr_revoked_at: Time.current)

  def self.generate_token = SecureRandom.urlsafe_base64(18)

  private

  def ensure_qr_token
    self.qr_token ||= self.class.generate_token
    self.qr_issued_at ||= Time.current
  end
end
