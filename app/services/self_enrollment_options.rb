# Chỗ trống mà phụ huynh tự chọn được khi tái ký trên PWA.
#
# Khác với màn hình của sale: phụ huynh không được nhìn thấy toàn bộ bức tranh
# vận hành của hồ. Ở đây chỉ hiện những gì họ cần để quyết định — khung giờ nào
# còn nhận, thầy nào dạy, còn mấy chỗ — và chỉ trong ĐÚNG hồ con họ đang học
# (OQ-23), với giáo viên thuộc trung tâm (không phải giờ thuê hồ).
class SelfEnrollmentOptions
  Slot = Struct.new(:teacher, :weekday, :hour, :swim_class, :seats_left, keyword_init: true) do
    def new_class? = swim_class.nil?
    def key = "#{teacher.id}:#{weekday}:#{hour}"
    def label = "#{%w[CN T2 T3 T4 T5 T6 T7][weekday]} · #{format('%02d:00', hour)}"
  end

  LOOKAHEAD_WEEKS = 4

  def initialize(pool:, student: nil)
    @pool = pool
    @student = student
  end

  # Lớp nhóm đang chạy còn chỗ — ưu tiên hiện trước vì học nhóm rẻ hơn và mở lớp
  # mới cho một học viên là lãng phí một khung giờ của giáo viên.
  def open_classes
    @open_classes ||= SwimClass.teaching.classes.where(pool_id: @pool.id)
                               .includes(:teacher, :course, enrollments: :student).to_a
                               .select { |c| c.seats_left.positive? && !already_in?(c) }
                               .map do |cls|
      Slot.new(teacher: cls.teacher, weekday: cls.weekday_list.first, hour: cls.start_hour,
               swim_class: cls, seats_left: cls.seats_left)
    end
  end

  # Khung giáo viên đã đăng ký dạy nhưng chưa có lớp — mở lớp mới ở đây.
  def free_slots
    @free_slots ||= begin
      months = [Date.current.beginning_of_month, Date.current.next_month.beginning_of_month]
      busy = SwimClass.teaching.where(pool_id: @pool.id).flat_map do |cls|
        cls.weekday_list.map { |wd| "#{cls.teacher_id}:#{wd}:#{cls.start_hour}" }
      end.to_set

      TeacherAvailability.where(pool_id: @pool.id, month: months).submitted
                         .includes(teacher: [:user, :teacher_level])
                         .select { |a| a.teacher.staff? && a.teacher.active? }
                         .reject { |a| busy.include?("#{a.teacher_id}:#{a.weekday}:#{a.hour}") }
                         .uniq { |a| "#{a.teacher_id}:#{a.weekday}:#{a.hour}" }
                         .sort_by { |a| [a.weekday, a.hour] }
                         .first(24)
                         .map do |a|
        Slot.new(teacher: a.teacher, weekday: a.weekday, hour: a.hour,
                 swim_class: nil, seats_left: a.teacher.capacity)
      end
    end
  end

  # Ngày bắt đầu gợi ý cho một khung: lần xuất hiện gần nhất mà hồ còn mở cửa,
  # tính từ tuần sau để phụ huynh có thời gian sắp xếp.
  def suggested_start(weekday)
    from = Date.current + 3
    (from..(from + LOOKAHEAD_WEEKS.weeks)).find { |d| d.wday == weekday && @pool.open_on?(d) }
  end

  # Gói bán được cho khách tái ký, kèm giá tại hồ này.
  def packages
    @packages ||= Package.sellable.ordered.includes(:course, :price_list_items).to_a
                         .select { |p| p.price_for(@pool).present? }
  end

  private

  def already_in?(cls)
    return false if @student.nil?
    cls.active_enrollments.any? { |e| e.student_id == @student.id }
  end
end
