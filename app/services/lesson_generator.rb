# Sinh các buổi học của một lớp từ khung lặp (thứ trong tuần + giờ), bỏ qua ngày
# hồ đóng cửa và ngày nghỉ lễ.
#
# Nguyên tắc: KHÔNG bao giờ đụng vào buổi đã diễn ra. Sinh lại chỉ thêm phần
# còn thiếu ở tương lai — nếu không, một lần bấm nhầm sẽ xoá mất lịch sử điểm
# danh và chấm công của cả lớp.
class LessonGenerator
  MAX_LOOKAHEAD_DAYS = 730 # chặn vòng lặp vô hạn khi khung lặp rỗng

  def initialize(swim_class)
    @swim_class = swim_class
    @pool = swim_class.pool
    @course = swim_class.course
  end

  # Sinh đủ số buổi của khoá. Trả về mảng Lesson vừa tạo.
  def call(total: nil)
    total ||= @swim_class.total_sessions
    weekdays = @swim_class.weekday_list
    return [] if weekdays.empty?

    existing = @swim_class.lessons.order(:session_index).to_a
    next_index = (existing.map(&:session_index).compact.max || 0) + 1
    return [] if next_index > total

    cursor = start_cursor(existing)
    created = []

    while next_index <= total && (cursor - start_date).to_i <= MAX_LOOKAHEAD_DAYS
      if weekdays.include?(cursor.wday) && open_on?(cursor)
        created << build_lesson(cursor, next_index)
        next_index += 1
      end
      cursor += 1
    end

    Lesson.insert_all(created.map(&:attributes_for_insert)) if created.any?
    @swim_class.lessons.reload.where(session_index: created.map(&:session_index)).to_a
  end

  # Dời toàn bộ buổi CHƯA diễn ra sang khung giờ / giáo viên mới. Dùng khi admin
  # sửa lớp, không dùng cho học bù một buổi lẻ.
  def reschedule_future!(weekdays: nil, start_hour: nil, teacher: nil, from: Date.current)
    scope = @swim_class.lessons.where("date >= ?", from).where(status: "scheduled")
    indexes = scope.pluck(:session_index)
    scope.destroy_all
    @swim_class.update!(
      weekdays: weekdays || @swim_class.weekdays,
      start_hour: start_hour || @swim_class.start_hour,
      teacher: teacher || @swim_class.teacher
    )
    regenerate_from(from, indexes)
  end

  private

  def start_date = @swim_class.start_date

  def start_cursor(existing)
    last = existing.map(&:date).max
    last ? last + 1 : start_date
  end

  # Hồ đóng cửa hôm đó (giờ mở cửa hoặc ngày nghỉ lễ) thì bỏ qua, không sinh buổi.
  def open_on?(date)
    hours = @pool.slot_hours_on(date)
    hours.include?(@swim_class.start_hour)
  end

  def regenerate_from(from, indexes)
    weekdays = @swim_class.weekday_list
    return [] if weekdays.empty? || indexes.empty?

    cursor = from
    created = []
    indexes.sort.each do |index|
      cursor += 1 until weekdays.include?(cursor.wday) && open_on?(cursor)
      created << build_lesson(cursor, index)
      cursor += 1
    end
    Lesson.insert_all(created.map(&:attributes_for_insert)) if created.any?
    created
  end

  def build_lesson(date, index)
    # nil khi kỳ thi được xếp riêng ngoài khoá (OQ-25) — khi đó không buổi nào
    # trong khoá được đánh dấu là buổi thi.
    exam_index = @course&.exam_session || @swim_class.workspace.exam_session_index
    Row.new(
      workspace_id: @swim_class.workspace_id,
      pool_id: @swim_class.pool_id,
      teacher_id: @swim_class.teacher_id,
      swim_class_id: @swim_class.id,
      date: date,
      start_hour: @swim_class.start_hour,
      session_index: index,
      exam: exam_index.present? && index == exam_index,
      status: "scheduled"
    )
  end

  # Dòng chuẩn bị cho insert_all — tránh khởi tạo hàng trăm ActiveRecord object
  # chỉ để ghi một lần (một lớp 12 buổi × nhiều lớp thì cộng dồn rất nhanh).
  Row = Struct.new(:workspace_id, :pool_id, :teacher_id, :swim_class_id, :date, :start_hour,
                   :session_index, :exam, :status, keyword_init: true) do
    def attributes_for_insert
      to_h.merge(created_at: Time.current, updated_at: Time.current)
    end
  end
end
