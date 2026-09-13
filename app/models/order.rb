# Đơn hàng của trung tâm thu của phụ huynh (FR-220). KHÁC với Invoice — hoá đơn
# thuê bao nền tảng mà trung tâm trả cho chúng ta.
class Order < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[unpaid paid cancelled refunded].freeze
  STATUS_LABELS = { "unpaid" => "Chờ thanh toán", "paid" => "Đã thanh toán",
                    "cancelled" => "Đã huỷ", "refunded" => "Đã hoàn" }.freeze
  KINDS = %w[course renewal day_pass rental].freeze
  KIND_LABELS = { "course" => "Khoá học", "renewal" => "Tái ký",
                  "day_pass" => "Vé lẻ", "rental" => "Thuê hồ" }.freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :household, optional: true
  belongs_to :student, optional: true
  belongs_to :enrollment, optional: true
  belongs_to :package, optional: true
  belongs_to :sale, class_name: "User", optional: true
  has_many :payments, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :unpaid, -> { where(status: "unpaid") }
  scope :paid,   -> { where(status: "paid") }
  # OQ-26 — hai dòng doanh thu tách bạch vì biên lợi nhuận rất khác nhau.
  scope :course_revenue, -> { paid.where.not(kind: "rental") }
  scope :rental_revenue, -> { paid.where(kind: "rental") }

  before_create :assign_code

  def paid?   = status == "paid"
  def unpaid? = status == "unpaid"
  def status_label = STATUS_LABELS[status]
  def kind_label   = KIND_LABELS[kind]
  def total = amount - discount

  # Ghi nhận thanh toán. Khoá dòng + kiểm tra lại nên webhook PayOS gọi hai lần
  # cũng chỉ ghi nhận một lần (chống ghi nhận trùng — FR-223 bước 6).
  def apply_payment!(method: "payos", gateway_response: {}, recorded_by: nil)
    with_lock do
      return false if paid?
      update!(status: "paid", paid_at: Time.current, gateway_response: gateway_response)
      payments.create!(workspace: workspace, amount: total, method: method,
                       paid_at: Time.current, recorded_by: recorded_by)
    end
    true
  end

  def mark_failed!(gateway_response: {})
    update!(gateway_response: gateway_response) if unpaid?
  end

  # Mã đơn PayOS mới trước mỗi lần mở checkout, để link cũ đã huỷ/hết hạn không
  # chặn lần thanh toán sau.
  def reassign_payos_code!
    update!(payos_order_code: 73_100_000_000 + SecureRandom.random_number(100_000_000),
            checkout_url: nil)
  end

  private

  def assign_code
    self.code ||= loop do
      candidate = "DH#{Time.current.strftime('%y%m')}#{SecureRandom.random_number(10_000).to_s.rjust(4, '0')}"
      break candidate unless Order.unscoped.exists?(code: candidate)
    end
  end
end
