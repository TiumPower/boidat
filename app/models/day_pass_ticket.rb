# Vé lẻ dùng một lần cho khách vãng lai (FR-214).
# Cố tình KHÔNG đăng ký khuôn mặt: xin đồng ý xử lý dữ liệu sinh trắc học cho
# một lượt bơi là quá nặng so với giá trị giao dịch (OQ-13).
class DayPassTicket < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :pool
  belongs_to :order, optional: true
  belongs_to :issued_by, class_name: "User", optional: true

  validates :code, presence: true, uniqueness: true
  validates :valid_on, presence: true

  before_validation :assign_code, on: :create

  scope :today, -> { where(valid_on: Date.current) }
  scope :unused, -> { where(used_at: nil) }

  def used? = used_at.present?
  def expired? = valid_on < Date.current

  def usable?
    return false if used?
    return false if expired?
    true
  end

  def redeem!
    return false unless usable?
    update!(used_at: Time.current)
  end

  def status_label
    return "Đã dùng" if used?
    return "Hết hạn" if expired?
    "Còn hiệu lực"
  end

  private

  def assign_code
    self.code ||= loop do
      candidate = "VE#{SecureRandom.alphanumeric(8).upcase}"
      break candidate unless DayPassTicket.unscoped.exists?(code: candidate)
    end
  end
end
