# Gợi ý lịch học bù theo đúng thứ tự ưu tiên khách đã chốt (FR-211 bước 5):
#
#   ① giáo viên đang dạy, khung giờ khác còn trống
#   ② giáo viên khác **cùng level**
#   ③ giáo viên có khoá học tương tự
#
# Thứ tự này không phải trang trí: phụ huynh gắn bó với người thầy chứ không
# gắn bó với khung giờ, nên giữ thầy được ưu tiên hơn giữ giờ.
class MakeupOptions
  Option = Struct.new(:lesson, :teacher, :priority, :label, :seats_left, keyword_init: true) do
    def available? = seats_left.to_i.positive?
  end

  LOOKAHEAD_DAYS = 21

  def initialize(enrollment:, from_lesson:, at: Date.current)
    @enrollment = enrollment
    @from_lesson = from_lesson
    @student = enrollment.student
    @pool = enrollment.pool
    @origin_class = enrollment.swim_class
    @from = [at, from_lesson&.date || at].max
  end

  # Trả về danh sách đã sắp xếp theo độ ưu tiên, bỏ các lớp đã kín chỗ.
  def call
    (same_teacher + same_level + similar_course)
      .uniq { |o| o.lesson.id }
      .reject { |o| o.lesson.swim_class_id == @origin_class.id && o.lesson.id == @from_lesson&.id }
      .select(&:available?)
      .sort_by { |o| [o.priority, o.lesson.date, o.lesson.start_hour] }
      .first(12)
  end

  private

  # ① Cùng thầy, khung giờ khác — giữ nguyên người dạy là ưu tiên số một.
  def same_teacher
    candidate_lessons.select { |l| l.teacher_id == @origin_class.teacher_id }.map do |lesson|
      Option.new(lesson: lesson, teacher: lesson.teacher, priority: 1,
                 label: "Vẫn #{lesson.teacher.display_name}, khung giờ khác",
                 seats_left: lesson.swim_class.seats_left)
    end
  end

  # ② Giáo viên khác CÙNG LEVEL — cùng sức chứa, cùng chuẩn chuyên môn.
  def same_level
    level_id = @origin_class.teacher.teacher_level_id
    return [] if level_id.nil?

    candidate_lessons.select { |l| l.teacher.teacher_level_id == level_id && l.teacher_id != @origin_class.teacher_id }
                     .map do |lesson|
      Option.new(lesson: lesson, teacher: lesson.teacher, priority: 2,
                 label: "Cùng #{lesson.teacher.level_label}", seats_left: lesson.swim_class.seats_left)
    end
  end

  # ③ Giáo viên có khoá học tương tự — nội dung buổi khớp thì học viên không bị hụt.
  def similar_course
    course_id = @origin_class.course_id
    return [] if course_id.nil?

    candidate_lessons.select { |l| l.swim_class.course_id == course_id }.map do |lesson|
      Option.new(lesson: lesson, teacher: lesson.teacher, priority: 3,
                 label: "Cùng khoá #{lesson.swim_class.course&.name}",
                 seats_left: lesson.swim_class.seats_left)
    end
  end

  # Buổi sắp tới tại ĐÚNG hồ của học viên (OQ-23 — không có học bù xuyên cơ sở).
  def candidate_lessons
    @candidate_lessons ||= Lesson.where(pool_id: @pool.id, status: "scheduled")
                                 .where(date: @from..(@from + LOOKAHEAD_DAYS))
                                 .where(swim_class_id: SwimClass.teaching.classes.where(pool_id: @pool.id).select(:id))
                                 .includes(swim_class: [:course, :teacher, { enrollments: :student }],
                                           teacher: [:user, :teacher_level])
                                 .order(:date, :start_hour).to_a
                                 .reject { |l| already_enrolled?(l) }
  end

  # Không gợi ý buổi mà em đó vốn đã có mặt.
  def already_enrolled?(lesson)
    lesson.swim_class.active_enrollments.any? { |e| e.student_id == @student.id }
  end
end
