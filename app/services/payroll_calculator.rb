# Chấm công tự động cho một buổi dạy (BR-02, FR-210, FR-301).
#
# Công thức: công = hệ số theo sĩ số × 1 tiết (60 phút). Bảng hệ số nằm trong
# cấu hình của trung tâm, không hard-code (OQ-04/05).
#
# Hai quyết định nghiệp vụ được cài ở đây, cả hai đều đọc từ cấu hình:
#   · Tính theo sĩ số ĐĂNG KÝ hay sĩ số CÓ MẶT (OQ-06). Khách đã chốt **CÓ MẶT**:
#     học viên vắng thì giáo viên không được tính công cho suất đó. Vì vậy công
#     của một buổi thay đổi theo từng lượt điểm danh, và buổi không ai đến thì
#     không phát sinh dòng công nào.
#   · Nhận xét có chặn lương không (OQ-22). Mặc định KHÔNG — gộp hai nghiệp vụ
#     không liên quan sẽ gây tranh chấp lương khi thầy quên nhận xét.
#
# Giáo viên THUÊ HỒ không có chấm công (FR-225) — họ là khách thuê, không phải
# nhân sự của trung tâm.
class PayrollCalculator
  def initialize(lesson)
    @lesson = lesson
    @workspace = lesson.workspace
    @teacher = lesson.teacher
  end

  # Tính (hoặc tính lại) dòng công của buổi này. Trả về TimesheetEntry, hoặc nil
  # khi buổi không phát sinh công.
  def call
    return nil unless payable?

    entry = TimesheetEntry.find_or_initialize_by(workspace: @workspace, lesson: @lesson, teacher: @teacher)
    return entry if entry.locked? # kỳ đã chốt thì không tính lại

    count = headcount
    credits = @workspace.credits_for(count)

    # Không ai đến thì không có công (OQ-06 — tính theo sĩ số có mặt). Xoá luôn
    # dòng cũ thay vì để lại một dòng 0 công: bảng công của giáo viên phải là
    # danh sách buổi thực sự có tiền, không phải nhật ký mọi buổi từng xếp.
    if credits.zero?
      entry.destroy if entry.persisted?
      return nil
    end

    rate = @teacher.pay_rate
    entry.assign_attributes(
      pool: @lesson.pool, headcount: count, basis: basis, credits: credits,
      rate: rate, amount: (credits * rate).round, status: "pending"
    )
    entry.save!
    entry
  end

  # Sĩ số dùng để tính công. Mặc định là số học viên CÓ MẶT.
  def headcount
    if @workspace.credit_basis_registered?
      @lesson.swim_class.seats_taken
    else
      @lesson.attendances.count { |a| a.status == "present" }
    end
  end

  def basis = @workspace.credit_basis_registered? ? "registered" : "present"

  def payable?
    return false if @teacher.renter?                      # thuê hồ: không chấm công
    return false if @lesson.cancelled?
    return false if @lesson.exam? && !@workspace.exam_pays_credit?
    return false if @workspace.feedback_blocks_payroll? && !feedback_complete?
    true
  end

  # Chỉ dùng khi trung tâm bật tuỳ chọn "nhận xét mới được tính công".
  def feedback_complete?
    roster = @lesson.swim_class.active_enrollments.map(&:student_id)
    return true if roster.empty?
    (roster - @lesson.session_feedbacks.pluck(:student_id)).empty?
  end

  # Tính lại toàn bộ công của một giáo viên trong khoảng ngày (dùng sau khi sửa
  # điểm danh tay hoặc đổi cấu hình hệ số công).
  def self.recalculate_range(teacher:, from:, to:)
    Lesson.where(teacher_id: teacher.id, date: from..to)
          .where.not(status: "cancelled")
          .find_each { |lesson| new(lesson).call }
  end

  # Tổng hợp công cho màn hình bảng công.
  def self.summary_for(teacher:, from:, to:)
    entries = TimesheetEntry.where(teacher_id: teacher.id).in_range(from, to).includes(:lesson).to_a
    {
      entries: entries,
      credits: entries.sum(&:credits),
      amount: entries.sum(&:amount),
      lessons: entries.size,
      avg_headcount: entries.any? ? (entries.sum(&:headcount).to_f / entries.size).round(1) : 0
    }
  end
end
