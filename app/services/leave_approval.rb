# Duyệt đơn xin nghỉ của giáo viên (FR-211).
#
# Duyệt xong là một chuỗi hệ quả phải xảy ra trọn vẹn, nếu không phụ huynh sẽ
# tới hồ vào buổi đã bị huỷ:
#   huỷ buổi → KHÔNG trừ buổi của học viên (BR-10) → tạo yêu cầu học bù cho từng
#   em → thông báo BẮT BUỘC XÁC NHẬN cho phụ huynh (OQ-16) → admin theo dõi ai
#   chưa xác nhận để gọi điện.
class LeaveApproval
  def initialize(leave_request, actor:)
    @request = leave_request
    @actor = actor
    @workspace = leave_request.workspace
  end

  def approve!(note: nil)
    lessons = @request.lessons.includes(swim_class: { enrollments: :student }).to_a

    ActiveRecord::Base.transaction do
      @request.update!(status: "approved", reviewed_by: @actor, reviewed_at: Time.current,
                       review_note: note)
      lessons.each { |lesson| cancel_lesson(lesson) }
    end

    notify_affected(lessons)
    lessons.size
  end

  def reject!(note: nil)
    @request.update!(status: "rejected", reviewed_by: @actor, reviewed_at: Time.current,
                     review_note: note)
    notify_teacher(approved: false)
  end

  private

  def cancel_lesson(lesson)
    lesson.update!(status: "cancelled", cancel_reason: "Giáo viên nghỉ · đơn ##{@request.id}")
    # Buổi bị huỷ do giáo viên nghỉ thì học viên không mất buổi (BR-10). Nếu lỡ
    # đã điểm danh trước đó thì hoàn lại.
    lesson.attendances.each do |att|
      att.enrollment&.restore_session! if att.deducted
      att.destroy!
    end
    # Công của buổi bị huỷ cũng phải gỡ, nếu không giáo viên được trả cho buổi
    # chính mình xin nghỉ.
    lesson.timesheet_entry&.destroy unless lesson.timesheet_entry&.locked?

    lesson.swim_class.active_enrollments.each do |enrollment|
      MakeupRequest.find_or_create_by!(workspace: @workspace, enrollment: enrollment,
                                       from_lesson: lesson) do |m|
        m.pool = lesson.pool
        m.student = enrollment.student
        m.leave_request = @request
        m.origin = "teacher_leave"
        m.status = "pending"
        m.reason = @request.reason
      end
    end
  end

  def notify_affected(lessons)
    lessons.each do |lesson|
      lesson.swim_class.active_enrollments.each do |enrollment|
        guardians = enrollment.student.household.guardians.to_a
        next if guardians.empty?

        title = "#{lesson.teacher.display_name} nghỉ buổi #{I18n.l(lesson.date, format: '%d/%m')}"
        body = "Buổi này không bị trừ. Chọn một phương án cho #{enrollment.student.short_name}."
        guardians.each do |g|
          Notification.create!(workspace: @workspace, recipient: g, kind: "teacher_leave",
                               title: title, body: body, subject: lesson,
                               requires_ack: true, deep_link: "/notifications")
        end
        PushJob.perform_later(@workspace.id, "Guardian", guardians.map(&:id), title, body, "/notifications")
      end
    end
    notify_teacher(approved: true)
  end

  def notify_teacher(approved:)
    user = @request.teacher.user
    title = approved ? "Đơn xin nghỉ đã được duyệt" : "Đơn xin nghỉ bị từ chối"
    Notification.create!(workspace: @workspace, recipient: user, kind: "teacher_leave",
                         title: title, body: @request.review_note.to_s, subject: @request,
                         deep_link: "/teacher/leaves")
    PushJob.perform_later(@workspace.id, "User", [user.id], title, @request.review_note.to_s,
                          "/teacher/leaves")
  end
end
