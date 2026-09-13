class Package < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[full_course per_session day_pass pool_rental].freeze
  KIND_LABELS = {
    "full_course" => "Trọn khoá", "per_session" => "Gói lẻ theo buổi",
    "day_pass" => "Vé lẻ", "pool_rental" => "Thuê hồ theo giờ"
  }.freeze

  belongs_to :workspace
  belongs_to :course, optional: true
  has_many :price_list_items, dependent: :destroy

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :class_type, inclusion: { in: 1..4 }, allow_nil: true

  scope :ordered, -> { order(:position, :name) }
  scope :active,  -> { where(status: "active") }
  scope :sellable, -> { active.where(kind: %w[full_course per_session]) }

  accepts_nested_attributes_for :price_list_items, allow_destroy: true

  def kind_label = KIND_LABELS[kind]
  def active? = status == "active"
  def day_pass? = kind == "day_pass"
  def rental?   = kind == "pool_rental"

  # Vé lẻ và thuê hồ không gắn với khoá học nên không có loại lớp.
  def class_type_label = class_type ? "1:#{class_type}" : "—"

  def session_count = sessions.presence || course&.total_sessions

  def expiry_days = validity_days.presence || course&.expiry_days || workspace.package_validity_days

  def expires_on(from = Date.current) = from + expiry_days.days

  # Giá áp dụng cho một hồ tại một thời điểm: ưu tiên giá riêng của hồ, không có
  # thì lấy giá chung (pool_id NULL). Giá có hiệu lực theo thời gian nên tăng giá
  # không làm sai lệch các đơn đã bán.
  def price_for(pool, on: Date.current)
    candidates = price_list_items.select do |item|
      (item.pool_id.nil? || item.pool_id == pool&.id) &&
        (item.effective_from.nil? || item.effective_from <= on) &&
        (item.effective_to.nil? || item.effective_to >= on)
    end
    scoped = candidates.select { |i| i.pool_id == pool&.id }
    (scoped.presence || candidates).max_by { |i| i.effective_from || Date.new(2000, 1, 1) }&.price
  end

  def price_label(pool = nil)
    p = price_for(pool)
    p ? "#{ActiveSupport::NumberHelper.number_to_delimited(p)}đ" : "chưa đặt giá"
  end
end
