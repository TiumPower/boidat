# Bộ lọc kỳ báo cáo của cổng điều hành (FR-101): ngày / tuần / tháng / năm /
# khoảng tuỳ chọn, kèm kỳ liền trước để tính % so sánh.
#
# Là PORO chứ không phải concern vì view cần cầm nguyên đối tượng này (nhãn kỳ,
# kỳ trước, khoảng thời gian) chứ không chỉ một hash rời rạc.
class PeriodFilter
  KEYS = %w[day week month year custom].freeze
  LABELS = { "day" => "Ngày", "week" => "Tuần", "month" => "Tháng",
             "year" => "Năm", "custom" => "Tuỳ chọn" }.freeze

  attr_reader :key, :from, :to

  def initialize(key = nil, from = nil, to = nil, today: Date.current)
    @today = today
    @key = KEYS.include?(key.to_s) ? key.to_s : "month"
    if @key == "custom"
      f = parse(from) || today.beginning_of_month
      t = parse(to)   || today
      f, t = t, f if f > t
      @from, @to = f, t
    else
      @from, @to = bounds(@key)
    end
  end

  def range = @from.beginning_of_day..@to.end_of_day

  # Kỳ liền trước có cùng độ dài — dùng cho cột "so kỳ trước".
  def previous
    span = (@to - @from).to_i + 1
    prev_to = @from - 1
    prev_from = prev_to - (span - 1)
    self.class.custom(prev_from, prev_to)
  end

  def previous_range = previous.range

  def self.custom(from, to)
    new("custom", from.to_s, to.to_s)
  end

  def label = LABELS[key]

  def range_label
    return I18n.l(@from, format: "%d/%m/%Y") if @from == @to
    "#{I18n.l(@from, format: '%d/%m/%Y')} – #{I18n.l(@to, format: '%d/%m/%Y')}"
  end

  # Mỗi ngày/tuần/tháng trong kỳ — dùng để vẽ biểu đồ xu hướng (FR-104).
  def buckets
    case key
    when "day"  then [@from]
    when "week" then (@from..@to).to_a
    when "year" then (0..11).map { |i| @from.beginning_of_year + i.months }
    else (@from..@to).to_a
    end
  end

  # % thay đổi giữa hai con số, nil khi kỳ trước bằng 0 (không có gì để so).
  def self.delta(current, previous)
    return nil if previous.to_f.zero?
    ((current.to_f - previous.to_f) / previous.to_f * 100).round(1)
  end

  private

  def bounds(key)
    case key
    when "day"   then [@today, @today]
    when "week"  then [@today.beginning_of_week, @today.end_of_week]
    when "year"  then [@today.beginning_of_year, @today.end_of_year]
    else [@today.beginning_of_month, @today.end_of_month]
    end
  end

  def parse(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
