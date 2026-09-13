# Một lần thu tiền cho đơn hàng của trung tâm.
class Payment < ApplicationRecord
  acts_as_tenant(:workspace)

  METHODS = %w[payos cash transfer].freeze
  METHOD_LABELS = { "payos" => "PayOS", "cash" => "Tiền mặt", "transfer" => "Chuyển khoản" }.freeze

  belongs_to :workspace
  belongs_to :order
  belongs_to :recorded_by, class_name: "User", optional: true

  validates :method, inclusion: { in: METHODS }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def method_label = METHOD_LABELS[method]
end
