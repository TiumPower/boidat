# Các chỉ số của bảng điều khiển BOD (FR-102).
#
# Hai định nghĩa quan trọng đã chốt với khách, cài đúng ở đây:
#
# · **Tỷ lệ lấp đầy** = số tiết ĐÃ CÓ HỌC VIÊN ÷ tổng số tiết ĐÃ PHÂN LỊCH cho
#   giáo viên trong kỳ (OQ-11). "Công suất ban đầu" chính là mẫu số, hệ thống tự
#   tính từ lịch, không ai nhập tay. Cách tính này coi một tiết lớp 1:1 và một
#   tiết lớp 1:4 là như nhau — nếu sau này BOD muốn nhìn theo góc kinh doanh thì
#   thêm chỉ số "số chỗ đã bán ÷ tổng chỗ" mà không phải đổi cấu trúc dữ liệu.
#
# · **Doanh thu tách hai dòng**: khoá học và cho thuê hồ (OQ-26). Hai mô hình có
#   biên lợi nhuận rất khác nhau nên gộp lại là nhìn sai.
#
# Thêm một chỉ số không có trong list gốc nhưng bắt buộc phải có: **tỷ lệ vắng
# không báo**. Vì chính sách đã chốt là nghỉ không báo thì không trừ buổi
# (BR-12), slot bị bỏ trống mà không ai mất gì — nếu tỷ lệ này cao thì công suất
# thật của hồ thấp hơn nhiều so với con số "lấp đầy" trên dashboard (OQ-10).
class PoolMetrics
  def initialize(workspace:, pools:, period:)
    @workspace = workspace
    @pool_ids = Array(pools).map { |p| p.respond_to?(:id) ? p.id : p }
    @period = period
    @range = period.range
    @date_range = period.from..period.to
  end

  def call
    {
      revenue_course: revenue_course,
      revenue_rental: revenue_rental,
      students_active: students_active,
      students_new: students_new,
      courses_running: courses_running,
      lessons_taught: lessons_taught,
      credits: credits,
      fill_rate: fill_rate,
      fill_detail: fill_detail,
      no_show_rate: no_show_rate,
      unpaid_amount: unpaid_amount,
      expiring_soon: expiring_soon,
      credit_spread: credit_spread
    }
  end

  # So với kỳ liền trước — cột "% so kỳ trước" của FR-101.
  def with_comparison
    current = call
    previous = self.class.new(workspace: @workspace, pools: @pool_ids, period: @period.previous).call
    current.merge(
      deltas: {
        revenue_course: PeriodFilter.delta(current[:revenue_course], previous[:revenue_course]),
        students_active: PeriodFilter.delta(current[:students_active], previous[:students_active]),
        lessons_taught: PeriodFilter.delta(current[:lessons_taught], previous[:lessons_taught]),
        credits: PeriodFilter.delta(current[:credits], previous[:credits]),
        fill_rate: PeriodFilter.delta(current[:fill_rate], previous[:fill_rate])
      },
      previous: previous
    )
  end

  # Doanh thu theo từng hồ — bảng xếp hạng của FR-104.
  def by_pool
    Pool.where(id: @pool_ids).ordered.map do |pool|
      single = self.class.new(workspace: @workspace, pools: [pool], period: @period).call
      { pool: pool, revenue: single[:revenue_course] + single[:revenue_rental],
        fill_rate: single[:fill_rate], detail: single[:fill_detail],
        students: single[:students_active] }
    end
  end

  # Top giáo viên theo công.
  def teacher_ranking(limit: 8)
    TimesheetEntry.where(pool_id: @pool_ids).in_range(@period.from, @period.to)
                  .group(:teacher_id).sum(:credits)
                  .sort_by { |_id, credits| -credits }
                  .first(limit)
                  .filter_map do |teacher_id, credits|
      teacher = Teacher.includes(:user, :teacher_level).find_by(id: teacher_id)
      next if teacher.nil?
      { teacher: teacher, credits: credits.to_f.round(1) }
    end
  end

  # Gói bán chạy trong kỳ.
  def package_ranking(limit: 6)
    Order.where(pool_id: @pool_ids, status: "paid", paid_at: @range)
         .where.not(package_id: nil).group(:package_id)
         .select("package_id, COUNT(*) AS sold, SUM(amount) AS revenue")
         .order("sold DESC").limit(limit)
         .filter_map do |row|
      package = Package.find_by(id: row.package_id)
      next if package.nil?
      { package: package, sold: row.sold, revenue: row.revenue.to_i }
    end
  end

  # Chuỗi doanh thu theo bucket của kỳ — biểu đồ xu hướng (FR-104).
  def revenue_series
    paid = Order.where(pool_id: @pool_ids, status: "paid", paid_at: @range)
                .group(:kind).group("DATE(paid_at)").sum(:amount)
    @period.buckets.map do |day|
      course = paid.sum { |(kind, date), amount| kind == "rental" || date != day ? 0 : amount }
      rental = paid.sum { |(kind, date), amount| kind == "rental" && date == day ? amount : 0 }
      { date: day, course: course, rental: rental }
    end
  end

  private

  def revenue_course
    Order.where(pool_id: @pool_ids, paid_at: @range).course_revenue.sum(:amount)
  end

  def revenue_rental
    Order.where(pool_id: @pool_ids, paid_at: @range).rental_revenue.sum(:amount)
  end

  def students_active
    Student.where(pool_id: @pool_ids, status: "active")
           .where(id: Enrollment.active.select(:student_id)).count
  end

  def students_new
    Student.where(pool_id: @pool_ids, created_at: @range).count
  end

  def courses_running
    SwimClass.teaching.classes.where(pool_id: @pool_ids).count
  end

  # Tiết đã dạy = buổi đã hoàn thành (có ít nhất một học viên điểm danh).
  def lessons_taught
    Lesson.where(pool_id: @pool_ids, date: @date_range, status: "done").count
  end

  def credits
    TimesheetEntry.where(pool_id: @pool_ids).in_range(@period.from, @period.to).sum(:credits).to_f.round(1)
  end

  # Mẫu số của tỷ lệ lấp đầy: tổng tiết đã phân lịch cho giáo viên trong kỳ.
  def scheduled_lessons
    @scheduled_lessons ||= Lesson.where(pool_id: @pool_ids, date: @date_range)
                                 .where.not(status: "cancelled").count
  end

  # Tử số: tiết đã có học viên.
  def filled_lessons
    @filled_lessons ||= Lesson.where(pool_id: @pool_ids, date: @date_range)
                              .where.not(status: "cancelled")
                              .where(swim_class_id: Enrollment.active.select(:swim_class_id))
                              .distinct.count
  end

  def fill_rate
    return 0 if scheduled_lessons.zero?
    (filled_lessons * 100.0 / scheduled_lessons).round
  end

  def fill_detail = "#{filled_lessons}/#{scheduled_lessons} tiết"

  # Vắng không báo: có tên trong lớp, buổi đã diễn ra, nhưng không có bản ghi
  # điểm danh nào.
  def no_show_rate
    done = Lesson.where(pool_id: @pool_ids, date: @date_range, status: "done").includes(:attendances).to_a
    return 0 if done.empty?

    expected = 0
    present = 0
    done.each do |lesson|
      roster = lesson.swim_class.active_enrollments.size
      expected += roster
      present += lesson.attendances.count { |a| a.status == "present" }
    end
    return 0 if expected.zero?
    (((expected - present).to_f / expected) * 100).round(1)
  end

  def unpaid_amount
    Order.where(pool_id: @pool_ids).unpaid.sum(:amount)
  end

  def expiring_soon
    Enrollment.active.where(pool_id: @pool_ids)
              .where(expires_on: Date.current..(Date.current + 30.days)).count
  end

  # Chênh lệch công giữa các giáo viên CÙNG cấp độ — chỉ số "phân bổ công bằng"
  # mà BR-07 yêu cầu nhưng không định nghĩa được. Mục tiêu đề xuất: ≤ 10%.
  def credit_spread
    rows = TimesheetEntry.where(pool_id: @pool_ids).in_range(@period.from, @period.to)
                         .group(:teacher_id).sum(:credits)
    return 0 if rows.size < 2

    by_level = rows.group_by { |teacher_id, _| Teacher.find_by(id: teacher_id)&.teacher_level_id }
    spreads = by_level.filter_map do |_level, entries|
      values = entries.map { |_id, credits| credits.to_f }
      next if values.size < 2 || values.sum.zero?
      mean = values.sum / values.size
      next if mean.zero?
      ((values.max - values.min) / mean * 100).round(1)
    end
    spreads.max || 0
  end
end
