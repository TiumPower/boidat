class User < ApplicationRecord
  # Nhân sự của trung tâm (BOD / admin / sale / lễ tân / giáo viên).
  # Không có :registerable — mọi tài khoản đều do Super Admin hoặc Admin tạo (FR-001, FR-218).
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable

  LOCALES = %w[vi en].freeze

  has_one_attached :avatar

  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :pool_assignments, dependent: :destroy
  has_many :pools, through: :pool_assignments
  has_one  :teacher, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  validates :name, presence: true
  validates :locale, inclusion: { in: LOCALES }

  def membership_for(workspace)
    return nil unless workspace
    memberships.find { |m| m.workspace_id == workspace.id } ||
      memberships.find_by(workspace_id: workspace.id)
  end

  def role_in(workspace) = membership_for(workspace)&.role

  # Hồ mà người này được phép thao tác trong workspace đang mở.
  # BOD thấy toàn bộ hồ; các vai trò khác chỉ thấy hồ được gán (FR-112).
  def accessible_pools(workspace)
    return Pool.none unless workspace
    scope = workspace.pools.order(:position, :name)
    return scope if role_in(workspace) == "bod"
    scope.where(id: pool_assignments.select(:pool_id))
  end

  def display_locale = LOCALES.include?(locale) ? locale : "vi"

  def initials
    name.to_s.split.map { |w| w[0] }.first(2).join.upcase.presence || email[0, 2].upcase
  end

  # Mã đăng nhập nhanh cho PWA: nhân viên mở hồ sơ trên web, quét QR bằng điện
  # thoại là vào thẳng ca trực (UX quầy điểm danh, màn 1).
  QUICK_LOGIN_TTL = 5.minutes

  def quick_login_token
    signed_id(purpose: :quick_login, expires_in: QUICK_LOGIN_TTL)
  end

  def self.find_by_quick_login_token(token)
    find_signed(token, purpose: :quick_login)
  end
end
