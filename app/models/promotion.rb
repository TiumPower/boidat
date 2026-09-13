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

  def value_label
    case kind
    when "bonus_sessions" then "+#{value} buổi"
    when "percent_off"    then "-#{value}%"
    when "gift"           then stock ? "còn #{stock}" : "hiện vật"
    when "referral_voucher" then "#{ActiveSupport::NumberHelper.number_to_delimited(value)}đ"
    else value.to_s
    end
  end
end
