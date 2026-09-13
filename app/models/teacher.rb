class Teacher < ApplicationRecord
  acts_as_tenant(:workspace)

  # staff  = giáo viên thuộc trung tâm — đủ nghiệp vụ: giáo án, nhận xét, chấm công.
  # renter = giáo viên THUÊ HỒ để tự dạy học viên của họ (FR-225, OQ-12).
  #          Trung tâm chỉ giữ khung giờ thuê + điểm danh trừ buổi, không quản lý sâu.
  KINDS    = %w[staff renter].freeze
  STATUSES = %w[active on_leave inactive].freeze
  STATUS_LABELS = { "active" => "Đang dạy", "on_leave" => "Tạm nghỉ", "inactive" => "Ngưng" }.freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :teacher_level, optional: true
  has_many :teacher_pools, dependent: :destroy
  has_many :pools, through: :teacher_pools
  has_many :availabilities, class_name: "TeacherAvailability", dependent: :destroy
  has_many :swim_classes, dependent: :restrict_with_error
  has_many :lessons, dependent: :restrict_with_error

  validates :kind,   inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :workspace_id }

  scope :staff,  -> { where(kind: "staff") }
  scope :renter, -> { where(kind: "renter") }
  scope :active, -> { where(status: "active") }
  scope :in_pool, ->(pool) { joins(:teacher_pools).where(teacher_pools: { pool_id: pool }) }

  delegate :name, :email, :phone, :avatar, to: :user

  def staff?  = kind == "staff"
  def renter? = kind == "renter"
  def active? = status == "active"
  def status_label = STATUS_LABELS[status]

  # Số học viên tối đa nhận trong một tiết — nếu chưa xếp level thì mặc định 1:1.
  def capacity = teacher_level&.max_students_per_slot || 1

  def level_label = teacher_level&.name || "Chưa xếp level"

  # "Thầy Minh" / "Cô Hạnh" — bộ UX luôn hiển thị kèm kính ngữ.
  def display_name
    honorific.present? ? "#{honorific} #{short_name}" : name
  end

  def short_name = name.to_s.split.last

  def honorific
    case user.title.to_s.downcase
    when "thầy", "thay", "mr" then "Thầy"
    when "cô", "co", "ms", "mrs" then "Cô"
    end
  end

  def pay_rate = teacher_level&.pay_rate_per_credit.to_i
end
