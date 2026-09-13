class PoolOperatingHour < ApplicationRecord
  acts_as_tenant(:workspace)

  WEEKDAY_LABELS = %w[Chủ\ nhật Thứ\ 2 Thứ\ 3 Thứ\ 4 Thứ\ 5 Thứ\ 6 Thứ\ 7].freeze

  belongs_to :workspace
  belongs_to :pool

  validates :weekday, inclusion: { in: 0..6 }
  validate  :closes_after_opens

  scope :ordered, -> { order(:weekday) }

  def weekday_label = WEEKDAY_LABELS[weekday]

  def range_label
    return "Nghỉ" if closed? || opens_at.nil?
    "#{opens_at.strftime('%H:%M')} – #{closes_at.strftime('%H:%M')}"
  end

  private

  def closes_after_opens
    return if closed? || opens_at.blank? || closes_at.blank?
    errors.add(:closes_at, "phải sau giờ mở cửa") if closes_at <= opens_at
  end
end
