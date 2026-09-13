class Student < ApplicationRecord
  acts_as_tenant(:workspace)

  # center = học viên của trung tâm; renter = học viên của giáo viên thuê hồ (FR-225).
  KINDS    = %w[center renter].freeze
  STATUSES = %w[active graduated inactive].freeze

  belongs_to :workspace
  belongs_to :household
  belongs_to :pool               # OQ-23 — học viên khoá cứng theo hồ đã đăng ký
  belongs_to :guardian, optional: true
  has_one  :face_profile, dependent: :destroy
  has_many :biometric_consents, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :swim_classes, through: :enrollments
  has_many :attendances, dependent: :destroy
  has_many :session_feedbacks, dependent: :destroy
  has_many :orders, dependent: :nullify

  validates :name, presence: true
  validates :kind,   inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :active,  -> { where(status: "active") }
  scope :center,  -> { where(kind: "center") }
  scope :renters, -> { where(kind: "renter") }
  scope :in_pool, ->(pool) { where(pool_id: pool) }
  scope :with_face, -> { joins(:face_profile).where(face_profiles: { deleted_at: nil }) }
  scope :without_face, -> { where.missing(:face_profile) }

  def child? = age.present? && age < 16

  def age
    return nil if birthdate.blank?
    ((Date.current - birthdate) / 365.25).floor
  end

  def age_label = age ? "#{age} tuổi" : nil

  def short_name = name.to_s.split.last(2).join(" ")

  def face_registered? = face_profile.present? && face_profile.deleted_at.nil?

  # Điểm danh chỉ hợp lệ tại đúng hồ trực thuộc (FR-235, OQ-23).
  def attendable_at?(other_pool) = pool_id == other_pool&.id
end
