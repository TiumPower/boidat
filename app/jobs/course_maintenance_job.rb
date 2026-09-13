# Bảo trì vòng đời khoá học, chạy hằng ngày (BR-11 / FR-212b).
#
# Ba việc, làm theo đúng thứ tự:
#   1. Nhắc trước khi gói hết hạn — phụ huynh mất buổi mà không được báo trước
#      là nguồn khiếu nại chắc chắn.
#   2. Đóng khoá đã hết hạn 1 năm, số buổi chưa dùng mất hiệu lực.
#   3. Nhắc gia hạn khi còn ≤ n buổi (OQ-17 — đòn bẩy tái ký).
class CourseMaintenanceJob < ApplicationJob
  queue_as :default

  def perform
    ActsAsTenant.without_tenant do
      Workspace.where(status: %w[active trial]).find_each do |workspace|
        ActsAsTenant.with_tenant(workspace) do
          warn_expiring(workspace)
          close_expired(workspace)
          nudge_low_sessions(workspace)
        end
      rescue StandardError => e
        Rails.logger.error("[maintenance] #{workspace.subdomain}: #{e.class} #{e.message}")
      end
    end
  end

  private

  def warn_expiring(workspace)
    days = workspace.setting("expiry_warning_days").to_i
    target = Date.current + days
    Enrollment.active.where(expires_on: target).includes(student: { household: :guardians })
              .find_each do |enrollment|
      next if enrollment.sessions_left.zero?
      notify(workspace, enrollment.student,
             kind: "low_sessions",
             title: "Gói của #{enrollment.student.short_name} sắp hết hạn",
             body: "Còn #{enrollment.sessions_left} buổi, hạn dùng tới " \
                   "#{I18n.l(enrollment.expires_on, format: '%d/%m/%Y')}. " \
                   "Sau ngày đó số buổi chưa dùng sẽ không còn hiệu lực.")
    end
  end

  def close_expired(workspace)
    Enrollment.active.where("expires_on < ?", Date.current).find_each do |enrollment|
      enrollment.update!(status: "expired")
      notify(workspace, enrollment.student,
             kind: "low_sessions",
             title: "Khoá của #{enrollment.student.short_name} đã hết hạn",
             body: "Gói hết hạn ngày #{I18n.l(enrollment.expires_on, format: '%d/%m/%Y')}. " \
                   "Liên hệ trung tâm nếu bạn muốn đăng ký khoá mới.")
    end
  end

  def nudge_low_sessions(workspace)
    threshold = workspace.low_sessions_threshold
    Enrollment.active.find_each do |enrollment|
      next unless enrollment.sessions_left == threshold
      notify(workspace, enrollment.student,
             kind: "low_sessions",
             title: "#{enrollment.student.short_name} còn #{threshold} buổi",
             body: "Liên hệ trung tâm để giữ chỗ khoá tiếp theo với cùng thầy và khung giờ.")
    end
  end

  def notify(workspace, student, kind:, title:, body:)
    guardians = student.household.guardians.to_a
    return if guardians.empty?
    # Không gửi lại cùng một nội dung trong 7 ngày — job chạy hằng ngày, nếu
    # không chặn thì phụ huynh nhận đúng một thông báo mỗi sáng.
    return if Notification.where(recipient: guardians.first, title: title)
                          .where("created_at > ?", 7.days.ago).exists?

    guardians.each do |g|
      Notification.create!(workspace: workspace, recipient: g, kind: kind, title: title, body: body,
                           subject: student, deep_link: "/students/#{student.id}")
    end
    PushJob.perform_later(workspace.id, "Guardian", guardians.map(&:id), title, body, "/")
  end
end
