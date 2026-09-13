# Ghi nhận điểm danh và trừ buổi (BR-05). Dùng chung cho cả ba đường vào:
# quét khuôn mặt ở quầy, quét vé lẻ QR, và admin sửa tay trên bảng master data
# (FR-234) — để quy tắc trừ buổi chỉ nằm ở một chỗ duy nhất.
class AttendanceRecorder
  Result = Struct.new(:ok, :attendance, :status, :message, keyword_init: true) do
    def ok? = ok
    def [](k) = to_h[k]
  end

  def initialize(lesson:, student:, actor: nil, method: "manual", face_score: nil)
    @lesson = lesson
    @student = student
    @actor = actor
    @method = method
    @face_score = face_score
    @workspace = lesson.workspace
  end

  # Điểm danh có mặt: ghi nhận + trừ đúng 1 buổi khỏi gói.
  def check_in!
    existing = @lesson.attendances.find_by(student_id: @student.id)
    return failure("#{@student.name} đã được điểm danh buổi này rồi.") if existing&.present?

    enrollment = find_enrollment
    return failure("#{@student.name} không có đăng ký còn hiệu lực ở lớp này.") if enrollment.nil?
    return failure("Gói của #{@student.name} đã hết buổi.") if enrollment.sessions_left.zero?

    attendance = nil
    ActiveRecord::Base.transaction do
      attendance = existing || @lesson.attendances.new(workspace: @workspace, pool: @lesson.pool,
                                                       student: @student)
      deducted = enrollment.consume_session!(exam: @lesson.exam?)
      attendance.assign_attributes(enrollment: enrollment, actor: @actor, status: "present",
                                   method: @method, face_score: @face_score,
                                   deducted: deducted, checked_in_at: Time.current)
      attendance.save!
      enrollment.check_exam_eligibility!
    end

    Result.new(ok: true, attendance: attendance, status: "present",
               message: "Đã điểm danh #{@student.name} · còn #{enrollment.reload.sessions_left} buổi.")
  end

  # Bỏ điểm danh (admin tích nhầm): hoàn lại buổi đã trừ.
  def undo!
    attendance = @lesson.attendances.find_by(student_id: @student.id)
    return failure("Chưa điểm danh nên không có gì để bỏ.") if attendance.nil?

    ActiveRecord::Base.transaction do
      attendance.enrollment&.restore_session! if attendance.deducted
      attendance.destroy!
    end
    Result.new(ok: true, attendance: nil, status: "absent",
               message: "Đã bỏ điểm danh #{@student.name}, buổi đã được hoàn lại.")
  end

  def toggle!
    @lesson.attendances.exists?(student_id: @student.id) ? undo! : check_in!
  end

  private

  def failure(message) = Result.new(ok: false, attendance: nil, status: "error", message: message)

  def find_enrollment
    Enrollment.active.find_by(student_id: @student.id, swim_class_id: @lesson.swim_class_id)
  end
end
