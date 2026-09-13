class Pool < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[active paused closed].freeze

  belongs_to :workspace
  has_many :operating_hours, class_name: "PoolOperatingHour", dependent: :destroy
  has_many :holidays, class_name: "PoolHoliday", dependent: :destroy
  has_many :pool_assignments, dependent: :destroy
  has_many :users, through: :pool_assignments
  has_many :teacher_pools, dependent: :destroy
  has_many :teachers, through: :teacher_pools
  has_many :students, dependent: :restrict_with_error
  has_many :swim_classes, dependent: :destroy
  has_many :lessons, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :conversations, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :ordered, -> { order(:position, :name) }
  scope :active,  -> { where(status: "active") }

  accepts_nested_attributes_for :operating_hours, allow_destroy: true

  def active? = status == "active"

  def short_name = code.presence || name.to_s.split.last

  # Giờ mở cửa của một ngày cụ thể — nil nghĩa là hồ đóng hôm đó.
  def hours_on(date)
    return nil if holidays.exists?(date: date)
    row = operating_hours.find { |h| h.weekday == date.wday } ||
          operating_hours.find_by(weekday: date.wday)
    return nil if row.nil? || row.closed?
    [row.opens_at, row.closes_at]
  end

  def open_on?(date) = hours_on(date).present?

  # Các khung giờ dạy khả dụng trong ngày (mỗi tiết 60 phút).
  def slot_hours_on(date)
    open, close = hours_on(date)
    return [] if open.nil?
    (open.hour...close.hour).to_a
  end
end
