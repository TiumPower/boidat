# Bảng master data lịch học (FR-202) — màn hình chính của cổng vận hành.
#
# Điểm mấu chốt của yêu cầu: bảng phải hiện **cả slot đã có lớp lẫn slot còn
# trống**, nhìn một lần là thấy hết bức tranh của hồ. "Slot trống" không phải là
# mọi ô giờ rảnh của hồ, mà là **khung giờ giáo viên đã đăng ký dạy nhưng chưa
# có học viên** — đúng thứ sale cần để chốt lịch cho khách mới (FR-203).
class ScheduleBoard
  Slot = Struct.new(:date, :hour, :teacher, :lesson, :swim_class, keyword_init: true) do
    def free? = lesson.nil?
    def rental? = swim_class&.rental?
    def key = "#{date}-#{hour}-#{teacher.id}"

    def seats_left = swim_class&.seats_left
    def open_seat? = swim_class.present? && !swim_class.full?
  end

  attr_reader :pool, :days, :hours, :teachers

  def initialize(pool:, days:, teacher_scope: nil)
    @pool = pool
    @days = Array(days)
    @teachers = (teacher_scope || Teacher.in_pool(pool).where(status: %w[active on_leave]))
                .includes(:user, :teacher_level).to_a
    load_data
  end

  # Mọi slot của bảng: một dòng cho mỗi (ngày × giờ × giáo viên) có ý nghĩa —
  # tức là hoặc đã có buổi học, hoặc giáo viên đã đăng ký dạy khung đó.
  def slots
    @slots ||= days.flat_map do |date|
      pool_hours(date).flat_map do |hour|
        teachers.filter_map do |teacher|
          lesson = @lessons_by_key["#{date}-#{hour}-#{teacher.id}"]
          next Slot.new(date: date, hour: hour, teacher: teacher, lesson: lesson,
                        swim_class: lesson&.swim_class) if lesson
          next unless available?(teacher, date, hour)
          Slot.new(date: date, hour: hour, teacher: teacher, lesson: nil, swim_class: nil)
        end
      end
    end
  end

  def slots_on(date) = slots.select { |s| s.date == date }

  def slots_for(date, hour) = slots.select { |s| s.date == date && s.hour == hour }

  # Các giờ có gì đó để hiển thị — tránh vẽ 15 dòng giờ trống trơn.
  def active_hours
    @active_hours ||= slots.map(&:hour).uniq.sort
  end

  def free_slots   = slots.select(&:free?)
  def booked_slots = slots.reject(&:free?)

  def summary
    { classes: booked_slots.count { |s| !s.rental? },
      rentals: booked_slots.count(&:rental?),
      free: free_slots.size }
  end

  # Lọc "chỉ slot còn trống" — bộ lọc được sale dùng nhiều nhất (FR-203).
  def self.free_only(board) = board.free_slots

  private

  def pool_hours(date)
    @pool_hours ||= {}
    @pool_hours[date] ||= pool.slot_hours_on(date)
  end

  def load_data
    from, to = days.minmax
    @lessons_by_key = Lesson.where(pool_id: pool.id, date: from..to)
                            .where.not(status: "cancelled")
                            .includes(swim_class: [:course, :teacher],
                                      attendances: :student)
                            .index_by { |l| "#{l.date}-#{l.start_hour}-#{l.teacher_id}" }

    # Lịch đăng ký dạy của các tháng mà khoảng ngày này chạm tới.
    months = (from..to).map { |d| d.beginning_of_month }.uniq
    @availability = TeacherAvailability.where(pool_id: pool.id, month: months)
                                       .pluck(:teacher_id, :month, :weekday, :hour)
                                       .group_by { |tid, *| tid }
  end

  def available?(teacher, date, hour)
    rows = @availability[teacher.id] or return false
    month = date.beginning_of_month
    rows.any? { |_tid, m, wd, h| m == month && wd == date.wday && h == hour }
  end
end
