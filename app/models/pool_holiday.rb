class PoolHoliday < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :pool

  validates :date, presence: true, uniqueness: { scope: :pool_id }

  scope :upcoming, -> { where(date: Date.current..).order(:date) }
end
