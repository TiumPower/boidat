class Membership < ApplicationRecord
  # Bảy vai trò của SRS §3.1 rút về năm vai trò có tài khoản nội bộ.
  # (Phụ huynh R6 và học viên R7 đăng nhập bằng Guardian, không phải User.)
  ROLES = %w[bod admin sale receptionist teacher].freeze
  ROLE_LABELS = {
    "bod" => "Ban giám đốc", "admin" => "Quản lý hồ", "sale" => "Sale",
    "receptionist" => "Lễ tân", "teacher" => "Giáo viên"
  }.freeze

  belongs_to :user
  belongs_to :workspace

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id }

  def bod?          = role == "bod"
  def admin?        = role == "admin"
  def sale?         = role == "sale"
  def receptionist? = role == "receptionist"
  def teacher?      = role == "teacher"

  # Ai được vào cổng vận hành (S2)
  def operations? = bod? || admin? || sale?
  # Ai được vào cổng điều hành (S1)
  def executive?  = bod?
  # Ai được vào quầy điểm danh (S3)
  def front_desk? = bod? || admin? || receptionist?
  # Ai được tạo tài khoản nhân sự (FR-218) và duyệt đơn nghỉ (FR-211)
  def can_manage_staff? = bod? || admin?
  def can_manage_pricing? = bod? # OQ-20 — tách quyền sửa bảng giá lên cấp BOD

  def label = ROLE_LABELS[role] || role
end
