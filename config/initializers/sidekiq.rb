require "sidekiq"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  # Job định kỳ. Giờ ghi theo UTC; máy chủ chạy giờ Việt Nam (UTC+7) nên
  # 01:00 UTC = 08:00 sáng — đúng lúc phụ huynh mở điện thoại.
  config.on(:startup) do
    schedule = {
      # Đóng khoá hết hạn, nhắc sắp hết hạn, nhắc còn ít buổi (BR-11, OQ-17).
      "course_maintenance" => { "cron" => "0 1 * * *", "class" => "CourseMaintenanceJob", "queue" => "default" },
      # Nhắc buổi học trước 2 tiếng — Web Push là kênh duy nhất nên phải đúng lúc.
      "lesson_reminders" => { "cron" => "0 * * * *", "class" => "LessonReminderJob", "queue" => "default" },
      # Nhắc giáo viên nộp nhận xét quá hạn (nhắc, KHÔNG chặn lương — OQ-22).
      "feedback_reminders" => { "cron" => "0 12 * * *", "class" => "FeedbackReminderJob", "queue" => "default" },
      # Thuê bao nền tảng: tạo hoá đơn kỳ mới + tạm ngưng trung tâm quá hạn.
      "daily_billing_renewal" => { "cron" => "30 3 * * *", "class" => "BillingRenewalJob", "queue" => "default" },
      "deliver_scheduled_broadcasts" => { "cron" => "*/5 * * * *", "class" => "BroadcastDeliveryJob", "queue" => "default" }
    }
    if defined?(Sidekiq::Cron::Job)
      Sidekiq::Cron::Job.load_from_hash(schedule)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
