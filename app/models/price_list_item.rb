# Một dòng bảng giá: gói × hồ × khoảng hiệu lực. pool_id NULL = áp dụng mọi hồ.
class PriceListItem < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :package
  belongs_to :pool, optional: true

  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate  :range_valid

  scope :current, -> {
    where("effective_from IS NULL OR effective_from <= ?", Date.current)
      .where("effective_to IS NULL OR effective_to >= ?", Date.current)
  }

  def scope_label = pool&.name || "Tất cả hồ"

  def period_label
    return "Không giới hạn" if effective_from.nil? && effective_to.nil?
    [effective_from&.strftime("%d/%m/%Y") || "…", effective_to&.strftime("%d/%m/%Y") || "…"].join(" – ")
  end

  private

  def range_valid
    return if effective_from.blank? || effective_to.blank?
    errors.add(:effective_to, "phải sau ngày bắt đầu") if effective_to < effective_from
  end
end
