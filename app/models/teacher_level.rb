# Cấp độ giáo viên (FR-216). Level quyết định số học viên tối đa dạy cùng lúc
# (ràng buộc cứng của bộ xếp lịch, BR-04) và đơn giá quy đổi công → tiền (OQ-18).
class TeacherLevel < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  has_many :teachers, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :max_students_per_slot, numericality: { greater_than: 0, less_than_or_equal_to: 8 }

  scope :ordered, -> { order(:position, :name) }

  def pay_label = "#{ActiveSupport::NumberHelper.number_to_delimited(pay_rate_per_credit)}đ / công"
end
