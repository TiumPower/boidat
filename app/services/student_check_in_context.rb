# Học viên này có được điểm danh ở quầy đang trực không, và nếu có thì vào buổi nào?
#
# Đây là chỗ thực thi hai quy tắc quan trọng nhất của luồng điểm danh:
#   · FR-235 — tra cứu khuôn mặt chạy trên toàn hệ thống, nhưng nếu học viên
#     KHÔNG thuộc hồ đang trực thì chặn, và chỉ hiển thị tên + ảnh + tên cơ sở
#     trực thuộc; không lộ lịch học, gói học hay lịch sử thanh toán.
#   · OQ-23 — học viên đăng ký ở hồ nào thì chỉ học ở hồ đó.
class StudentCheckInContext
  Result = Struct.new(:student, :pool, :lesson, :enrollment, :reason, :wrong_pool, keyword_init: true) do
    def allowed? = reason.nil?
    def wrong_pool? = !!wrong_pool
    # Khi quét nhầm hồ, màn hình chỉ được hiển thị thông tin định danh tối thiểu.
    def minimal_only? = wrong_pool?
  end

  # Cửa sổ cho phép quét quanh giờ học: đến sớm 45 phút, muộn nhất 30 phút sau
  # khi tiết bắt đầu. Quét trước khi xuống nước nên không cần rộng hơn.
  EARLY_MINUTES = 45
  LATE_MINUTES  = 30

  def initialize(student:, pool:, at: Time.current)
    @student = student
    @pool = pool
    @at = at
  end

  def call
    if @student.pool_id != @pool.id
      return reject("Học viên này thuộc cơ sở #{@student.pool.name}, không có buổi học tại đây hôm nay.",
                    wrong_pool: true)
    end

    lesson = todays_lesson
    return reject("#{@student.name} không có buổi học tại #{@pool.name} hôm nay.") if lesson.nil?

    enrollment = Enrollment.active.find_by(student_id: @student.id, swim_class_id: lesson.swim_class_id)
    return reject("#{@student.name} không có đăng ký còn hiệu lực ở lớp này.", lesson: lesson) if enrollment.nil?
    return reject("Gói của #{@student.name} đã hết buổi.", lesson: lesson) if enrollment.sessions_left.zero?
    if enrollment.expires_on && enrollment.expires_on < Date.current
      return reject("Gói của #{@student.name} đã hết hạn #{I18n.l(enrollment.expires_on, format: '%d/%m/%Y')}.",
                    lesson: lesson)
    end
    if lesson.attendances.exists?(student_id: @student.id, status: "present")
      return reject("#{@student.name} đã điểm danh buổi này rồi.", lesson: lesson)
    end

    Result.new(student: @student, pool: @pool, lesson: lesson, enrollment: enrollment)
  end

  private

  def reject(reason, lesson: nil, wrong_pool: false)
    Result.new(student: @student, pool: @pool, lesson: lesson, reason: reason, wrong_pool: wrong_pool)
  end

  # Buổi của học viên hôm nay, trong cửa sổ thời gian cho phép quét.
  def todays_lesson
    candidates = Lesson.where(pool_id: @pool.id, date: @at.to_date, status: %w[scheduled done])
                       .where(swim_class_id: active_class_ids)
                       .order(:start_hour).to_a
    candidates.find { |l| within_window?(l) } || candidates.first
  end

  def active_class_ids
    Enrollment.active.where(student_id: @student.id).pluck(:swim_class_id)
  end

  def within_window?(lesson)
    (lesson.starts_at - EARLY_MINUTES.minutes) <= @at && @at <= (lesson.starts_at + LATE_MINUTES.minutes)
  end
end
