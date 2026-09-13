# Bằng chứng người giám hộ đã đồng ý xử lý dữ liệu sinh trắc học (FR-402).
# Lưu: ai tích, lúc nào, cho học viên nào, phiên bản điều khoản nào.
class BiometricConsent < ApplicationRecord
  acts_as_tenant(:workspace)

  CURRENT_TERMS_VERSION = "v1.2".freeze

  belongs_to :workspace
  belongs_to :student
  belongs_to :guardian, optional: true

  validates :terms_version, :consented_at, presence: true

  scope :active, -> { where(revoked_at: nil) }

  def self.record!(student:, guardian:, request: nil)
    create!(workspace: student.workspace, student: student, guardian: guardian,
            terms_version: CURRENT_TERMS_VERSION, consented_at: Time.current,
            ip: request&.remote_ip, user_agent: request&.user_agent)
  end

  def active? = revoked_at.nil?
  def revoke! = update!(revoked_at: Time.current)
end
