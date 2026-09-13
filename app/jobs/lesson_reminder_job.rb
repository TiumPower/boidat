# Nhắc buổi học sắp tới (FR-405). Chạy mỗi giờ, nhắc trước 2 tiếng.
#
# Vì hệ thống không dùng SMS/Zalo (A5), Web Push là kênh duy nhất — nên nhắc
# đúng lúc quan trọng hơn nhắc nhiều.
class LessonReminderJob < ApplicationJob
  queue_as :default

  WINDOW = 2.hours

  def perform
    ActsAsTenant.without_tenant do
      Workspace.where(status: %w[active trial]).find_each do |workspace|
        ActsAsTenant.with_tenant(workspace) { remind(workspace) }
      rescue StandardError => e
        Rails.logger.error("[reminder] #{workspace.subdomain}: #{e.class} #{e.message}")
      end
    end
  end

  private

  def remind(workspace)
    from = Time.current
    to = from + WINDOW

    Lesson.where(date: from.to_date..to.to_date, status: "scheduled")
          .includes(:teacher, :pool, swim_class: { enrollments: { student: { household: :guardians } } })
          .find_each do |lesson|
      next unless lesson.starts_at.between?(from, to)

      lesson.swim_class.active_enrollments.each do |enrollment|
        student = enrollment.student
        guardians = student.household.guardians.to_a
        next if guardians.empty?

        title = "#{student.short_name} có buổi học lúc #{lesson.time_label}"
        next if Notification.where(recipient: guardians.first, title: title)
                            .where("created_at > ?", 12.hours.ago).exists?

        body = "#{lesson.teacher.display_name} · #{lesson.pool.name}. " \
               "Đến sớm 15 phút và quét khuôn mặt tại quầy trước khi xuống nước."
        guardians.each do |g|
          Notification.create!(workspace: workspace, recipient: g, kind: "lesson_reminder",
                               title: title, body: body, subject: lesson, deep_link: "/")
        end
        PushJob.perform_later(workspace.id, "Guardian", guardians.map(&:id), title, body, "/")
      end
    end
  end
end
