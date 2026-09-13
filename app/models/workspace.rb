class Workspace < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  STATUSES = %w[pending trial active past_due suspended].freeze
  STATUS_LABELS = {
    "pending" => "Chờ duyệt", "trial" => "Dùng thử", "active" => "Đang hoạt động",
    "past_due" => "Quá hạn", "suspended" => "Tạm ngưng"
  }.freeze

  has_one_attached :logo

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :pools, dependent: :destroy
  has_many :teacher_levels, dependent: :destroy
  has_many :teachers, dependent: :destroy
  has_many :households, dependent: :destroy
  has_many :guardians, dependent: :destroy
  has_many :students, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :broadcasts, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :invoices, dependent: :destroy

  validates :name, :subdomain, presence: true
  validates :subdomain, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :status, inclusion: { in: STATUSES }

  before_validation :default_subdomain, on: :create

  # -- Status --------------------------------------------------------------
  def active?  = status == "active"
  def trial?   = status == "trial"
  def pending? = status == "pending"
  def onboarded? = settings["onboarded"] == true
  def status_label = STATUS_LABELS[status]

  def default_locale_sym
    %w[vi en].include?(locale_default) ? locale_default.to_sym : :vi
  end

  TRIAL_DAYS = 14

  def start_trial!(days = TRIAL_DAYS)
    update!(status: "trial", paid_until: days.days.from_now)
  end

  def payment_state
    return :suspended if status == "suspended" && !auto_suspended?
    return :trial     if trial? && subscription_active?
    return :paid      if subscription_active?
    return :owing     if paid_until.present?
    :new
  end

  PAYMENT_LABELS = {
    paid: "Đã thanh toán", trial: "Dùng thử", owing: "Đang nợ",
    suspended: "Tạm ngưng", new: "Chưa có kỳ"
  }.freeze
  def payment_label = PAYMENT_LABELS[payment_state]

  # -- Business configuration (§4 của kế hoạch) ----------------------------
  # Mọi quy tắc nghiệp vụ còn đang tranh luận với khách đều là tham số ở đây,
  # không hard-code trong code, để đổi chính sách không phải deploy lại.
  include BusinessSettings

  # -- Plan / limits -------------------------------------------------------
  def plan_record = @plan_record ||= Plan.for(plan)
  def monthly_price = active? ? plan_record.price.to_i : 0
  def full_access? = trial?

  def plan_allows?(feature)
    return true if full_access?
    case feature.to_sym
    when :custom_domain     then plan_record.allow_custom_domain
    when :face_recognition  then plan_record.allow_face_recognition
    when :auto_scheduler    then plan_record.allow_auto_scheduler
    when :chat              then plan_record.allow_chat
    else true
    end
  end

  def pool_limit    = full_access? ? nil : plan_record.max_pools
  def student_limit = full_access? ? nil : plan_record.max_students
  def teacher_limit = full_access? ? nil : plan_record.max_teachers

  def can_add_pool?(current = nil)
    within_limit?(pool_limit, current) { pools.count }
  end

  def can_add_student?(current = nil)
    within_limit?(student_limit, current) { students.where(status: "active").count }
  end

  def can_add_teacher?(current = nil)
    within_limit?(teacher_limit, current) { teachers.where(status: "active").count }
  end

  # -- Subscription --------------------------------------------------------
  GRACE_DAYS = 10

  def subscription_active? = paid_until.present? && paid_until >= Time.current

  def subscription_days_left
    return nil if paid_until.nil?
    ((paid_until - Time.current) / 1.day).ceil
  end

  def subscription_overdue_days
    return nil if paid_until.nil? || subscription_active?
    ((Time.current - paid_until) / 1.day).floor
  end

  def access_blocked_reason
    if status == "suspended"
      return auto_suspended? ? :unpaid : :suspended
    end
    d = subscription_overdue_days
    return :unpaid if d && d > GRACE_DAYS
    nil
  end
  def access_blocked? = access_blocked_reason.present?

  def owner = memberships.find_by(role: "bod")&.user || users.first
  def billing_email = owner&.email
  def contact_phone = branding_value("contact_phone").presence || owner&.phone.presence

  def auto_suspended? = status == "suspended" && settings["auto_suspended"] == true

  def auto_suspend_for_nonpayment!
    update!(status: "suspended", settings: settings.merge("auto_suspended" => true))
  end

  def auto_renew? = auto_renew

  def next_billing_period
    if subscription_active?
      d = paid_until.to_date + 1.day
      start = (d.day == 1) ? d : (d.beginning_of_month + 1.month)
    else
      start = Date.current.beginning_of_month
    end
    [start, start.end_of_month]
  end

  def first_billing_period
    return next_billing_period unless trial? && paid_until.present?
    start = paid_until.to_date + 1.day
    [start, start.end_of_month]
  end

  def checkout_quote(plan_key)
    price = Plan.for(plan_key).price
    period = if plan_key != plan && subscription_active? && !trial?
      [Date.current.beginning_of_month, Date.current.end_of_month]
    else
      first_billing_period
    end
    amount = prorated_amount(price, period)
    inv = invoices.pending.order(:period_start).first
    return [inv.amount, inv.period_start, inv.period_end] if inv && inv.plan == plan_key && inv.amount == amount

    [amount, period.first, period.last]
  end

  def prorated_amount(price, period = first_billing_period)
    price = price.to_i
    return price unless trial?
    s, e = period
    covered = (e - s).to_i + 1
    days_in_month = e.day
    return price if covered >= days_in_month
    ((price * covered) / days_in_month.to_f / 1000).round * 1000
  end

  # -- Theming (white-label cho từng trung tâm) ----------------------------
  DEFAULT_THEME = {
    "primary"      => "#0E7C86",  # xanh hồ bơi — lấy từ bộ UX
    "primary_2"    => "#2A6BB0",
    "on_primary"   => "#FFFFFF",
    "surface"      => "#F4F7F6",
    "surface_2"    => "#EAEFEE",
    "ink"          => "#0C2229",
    "ink_2"        => "#33525A",
    "line"         => "#C9D8D7",
    "radius"       => "16px",
    "font_display" => "Be Vietnam Pro",
    "font_body"    => "Be Vietnam Pro"
  }.freeze

  FONT_STACKS = {
    "Be Vietnam Pro"    => '"Be Vietnam Pro", ui-sans-serif, system-ui, sans-serif',
    "Plus Jakarta Sans" => '"Plus Jakarta Sans", ui-sans-serif, system-ui, sans-serif',
    "Inter"             => '"Inter", ui-sans-serif, system-ui, sans-serif',
    "Bricolage Grotesque" => '"Bricolage Grotesque", ui-sans-serif, system-ui, sans-serif'
  }.freeze

  # Bốn preset màu đúng như bộ UX đã vẽ ("Xanh hồ bơi / Tím chàm / Xanh dương / Hồng đất").
  THEME_PRESETS = {
    "pool_teal"  => { label: "Xanh hồ bơi", primary: "#0E7C86", primary_2: "#2A6BB0" },
    "indigo"     => { label: "Tím chàm",    primary: "#4C4B9B", primary_2: "#7A6BD0" },
    "ocean_blue" => { label: "Xanh dương",  primary: "#1F5FA6", primary_2: "#3BA5B0" },
    "clay_pink"  => { label: "Hồng đất",    primary: "#B8536B", primary_2: "#C2871A" }
  }.freeze

  def theme_value(key)
    stored = theme.presence&.dig(key.to_s).presence
    return stored if stored
    return readable_ink(theme_value(:primary)) if key.to_s == "on_primary"
    DEFAULT_THEME[key.to_s]
  end

  INK_LIGHT = "#FFFFFF".freeze
  INK_DARK  = "#111C1F".freeze

  # Chọn trắng hay gần-đen theo tỷ lệ tương phản WCAG, để màu thương hiệu nào
  # trung tâm chọn thì chữ trên nền đó vẫn đọc được.
  def readable_ink(hex)
    l = relative_luminance(hex)
    return DEFAULT_THEME["on_primary"] if l.nil?
    contrast(l, relative_luminance(INK_DARK)) > contrast(l, relative_luminance(INK_LIGHT)) ? INK_DARK : INK_LIGHT
  end

  def relative_luminance(hex)
    m = hex.to_s.delete("#")
    return nil unless m.match?(/\A[0-9a-fA-F]{6}\z/)
    r, g, b = m.scan(/../).map do |c|
      v = c.to_i(16) / 255.0
      v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4
    end
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  def contrast(l1, l2)
    hi, lo = [l1, l2].max, [l1, l2].min
    (hi + 0.05) / (lo + 0.05)
  end

  def css_radius
    r = theme_value(:radius).to_s.strip
    r.match?(/\A\d+(\.\d+)?\z/) ? "#{r}px" : (r.presence || "16px")
  end

  def resolved_theme = DEFAULT_THEME.merge(theme.presence || {})

  def font_stack(key)
    FONT_STACKS[theme_value(key)] || FONT_STACKS[DEFAULT_THEME[key]]
  end

  def apply_theme_preset!(key)
    preset = THEME_PRESETS[key.to_s] or return false
    update!(theme: theme.merge("primary" => preset[:primary], "primary_2" => preset[:primary_2]))
  end

  # -- Branding ------------------------------------------------------------
  DEFAULT_BRANDING = {
    "logo_text" => nil,
    "tagline"   => "Trung tâm dạy bơi",
    "city"      => nil,
    "contact_phone" => nil
  }.freeze

  def branding_value(key)
    branding.presence&.dig(key.to_s).presence || DEFAULT_BRANDING[key.to_s]
  end

  def logo_initials
    (branding_value("logo_text") || name).to_s.split.map { |w| w[0] }.first(2).join.upcase
  end

  private

  def within_limit?(limit, current)
    return true if limit.nil?
    current ||= ActsAsTenant.with_tenant(self) { yield }
    current < limit
  end

  def default_subdomain
    self.subdomain = slug if subdomain.blank? && slug.present?
    self.subdomain ||= name.to_s.parameterize
  end
end
