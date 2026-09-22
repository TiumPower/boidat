# Khuyến mãi — đúng 5 loại đang có trong bộ UX của cổng vận hành.
class Promotion < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[bonus_sessions percent_off sibling gift referral_voucher].freeze
  KIND_LABELS = {
    "bonus_sessions"   => "Tặng buổi",
    "percent_off"      => "Giảm phần trăm",
    "sibling"          => "Ưu đãi anh chị em",
    "gift"             => "Quà tặng hiện vật",
    "referral_voucher" => "Voucher giới thiệu"
  }.freeze

  belongs_to :workspace
  belongs_to :pool, optional: true

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:status, :name) }

  def kind_label = KIND_LABELS[kind]
  def active? = status == "active"

  def running?(on = Date.current)
    active? && (starts_on.nil? || starts_on <= on) && (ends_on.nil? || ends_on >= on)
  end

  # Đơn vị của cột `value` đổi theo `kind` — form nhập chỉ có một ô "Giá trị"
  # nên phải nói rõ đang nhập gì, nếu không BOD gõ 5 mà không ai biết là 5% hay
  # 5 buổi.
  VALUE_HINTS = {
    "bonus_sessions"   => "số buổi tặng thêm",
    "percent_off"      => "phần trăm giảm (%)",
    "sibling"          => "phần trăm giảm cho em thứ hai trở đi (%)",
    "gift"             => "để 0 — số lượng khai ở ô bên cạnh",
    "referral_voucher" => "mệnh giá voucher (đ)"
  }.freeze

  def self.value_hint(kind) = VALUE_HINTS[kind]

  def value_label
    case kind
    when "bonus_sessions"   then "+#{value} buổi"
    when "percent_off", "sibling" then "-#{value}%"
    when "gift"             then stock ? "còn #{stock}" : "hiện vật"
    when "referral_voucher" then "#{ActiveSupport::NumberHelper.number_to_delimited(value)}đ"
    else value.to_s
    end
  end
end
