# Nhắc giáo viên nộp nhận xét quá hạn (OQ-22).
#
# Nhận xét KHÔNG chặn lương — gộp hai nghiệp vụ không liên quan sẽ gây tranh chấp
# lương. Thay vào đó nó là nghĩa vụ riêng, có deadline và có nhắc. Job này chính
# là cái "nhắc" đó.
class FeedbackReminderJob < ApplicationJob
  queue_as :default

  def perform
    ActsAsTenant.without_tenant do
      Workspace.where(status: %w[active trial]).find_each do |workspace|
        ActsAsTenant.with_tenant(workspace) { remind(workspace) }
      rescue StandardError => e
        Rails.logger.error("[feedback] #{workspace.subdomain}: #{e.class} #{e.message}")
      end
    end
  end

  private

  def remind(workspace)
    deadline_hours = workspace.setting("feedback_deadline_hours").to_i
    cutoff = Time.current - deadline_hours.hours

    overdue = Lesson.where(status: "done").where("completed_at < ?", cutoff)
                    .where("completed_at > ?", cutoff - 3.days)
                    .includes(:teacher, :session_feedbacks, swim_class: { enrollments: :student })
                    .select do |lesson|
      roster = lesson.swim_class.active_enrollments.map(&:student_id)
      roster.any? && (roster - lesson.session_feedbacks.map(&:student_id)).any?
    end

    overdue.group_by(&:teacher).each do |teacher, lessons|
      user = teacher.user
      title = "Còn #{lessons.size} buổi chưa nhận xét"
      next if Notification.where(recipient: user, title: title)
                          .where("created_at > ?", 20.hours.ago).exists?

      body = "Quá hạn #{deadline_hours} giờ. Nhận xét không ảnh hưởng tới công của thầy/cô, " \
             "nhưng phụ huynh đang chờ."
      Notification.create!(workspace: workspace, recipient: user, kind: "feedback",
                           title: title, body: body, deep_link: "/teacher")
      PushJob.perform_later(workspace.id, "User", [user.id], title, body, "/teacher")
    end
  end
end
