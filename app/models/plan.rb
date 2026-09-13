class Plan < ApplicationRecord
  validates :key, :name, presence: true
  validates :key, uniqueness: true

  scope :ordered, -> { order(:position, :price) }

  # Định giá theo quy mô trung tâm: số hồ, số học viên đang hoạt động, số giáo viên.
  DEFAULTS = [
    { key: "starter", name: "Một hồ", price: 490_000, position: 0,
      max_pools: 1, max_students: 150, max_teachers: 10,
      allow_custom_domain: false, allow_face_recognition: false,
      allow_auto_scheduler: false, allow_chat: true,
      features: ["1 hồ bơi", "150 học viên", "10 giáo viên", "Lịch & điểm danh QR",
                 "Chấm công tự động", "PWA phụ huynh & giáo viên"] },
    { key: "pro", name: "Chuỗi hồ", price: 1_490_000, position: 1,
      max_pools: 5, max_students: 800, max_teachers: 60,
      allow_custom_domain: false, allow_face_recognition: true,
      allow_auto_scheduler: true, allow_chat: true,
      features: ["5 hồ bơi", "800 học viên", "Điểm danh khuôn mặt", "Xếp lịch tự động",
                 "Chat realtime", "Báo cáo BOD đa hồ"] },
    { key: "business", name: "Doanh nghiệp", price: 2_990_000, position: 2,
      max_pools: nil, max_students: nil, max_teachers: nil,
      allow_custom_domain: true, allow_face_recognition: true,
      allow_auto_scheduler: true, allow_chat: true,
      features: ["Không giới hạn hồ / học viên", "Tên miền riêng", "Ưu tiên hỗ trợ"] }
  ].freeze

  def self.lowest_allowing(feature)
    col = "allow_#{feature}"
    return nil unless column_names.include?(col)
    ordered.detect { |p| p.public_send(col) }
  end

  def self.for(key)
    find_by(key: key) || new(DEFAULTS.find { |d| d[:key] == key } || DEFAULTS.first)
  end

  def self.seed_defaults!
    DEFAULTS.each do |attrs|
      plan = find_or_initialize_by(key: attrs[:key])
      plan.assign_attributes(attrs)
      plan.save!
    end
  end

  def unlimited_pools?    = max_pools.nil?
  def unlimited_students? = max_students.nil?
  def price_label = "#{ActiveSupport::NumberHelper.number_to_delimited(price)}đ"

  def localized_features
    vals = I18n.t("merchant.plans.#{key}.features", default: nil)
    vals.is_a?(Array) ? vals : features
  end
end
