require "test_helper"

# Vòng đời khoá học chạy tự động (BR-11 / FR-212b): hết hạn thì đóng, sắp hết
# thì nhắc — phụ huynh mất buổi mà không được báo trước là khiếu nại chắc chắn.
class CourseMaintenanceJobTest < ActiveJob::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                                 start_hour: 17, weekdays: [1], start_date: 1.year.ago.to_date,
                                 status: "running")
    end
  end

  def enrollment(expires_on:, used: 0)
    with_tenant(@ws) do
      Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student, swim_class: @class,
                         sessions_total: 12, sessions_used: used, expires_on: expires_on,
                         status: "active")
    end
  end

  test "gói quá hạn thì tự đóng và báo cho phụ huynh" do
    enr = enrollment(expires_on: 1.day.ago.to_date, used: 5)
    CourseMaintenanceJob.new.perform
    with_tenant(@ws) do
      assert_equal "expired", enr.reload.status
      assert Notification.where(recipient: @c.guardian).where("title ILIKE ?", "%hết hạn%").exists?
    end
  end

  test "nhắc trước khi hết hạn đúng số ngày cấu hình" do
    days = @ws.setting("expiry_warning_days").to_i
    enrollment(expires_on: Date.current + days, used: 5)
    CourseMaintenanceJob.new.perform
    with_tenant(@ws) do
      assert Notification.where(recipient: @c.guardian).where("title ILIKE ?", "%sắp hết hạn%").exists?
    end
  end

  test "nhắc gia hạn khi còn đúng ngưỡng buổi (OQ-17)" do
    threshold = @ws.low_sessions_threshold
    enrollment(expires_on: 6.months.from_now.to_date, used: 12 - threshold)
    CourseMaintenanceJob.new.perform
    with_tenant(@ws) do
      assert Notification.where(recipient: @c.guardian)
                         .where("title ILIKE ?", "%còn #{threshold} buổi%").exists?
    end
  end

  test "chạy hai ngày liên tiếp không spam cùng một thông báo" do
    enrollment(expires_on: 1.day.ago.to_date, used: 5)
    CourseMaintenanceJob.new.perform
    count = with_tenant(@ws) { Notification.where(recipient: @c.guardian).count }
    CourseMaintenanceJob.new.perform
    assert_equal count, with_tenant(@ws) { Notification.where(recipient: @c.guardian).count }
  end

  test "gói còn hạn và còn nhiều buổi thì không bị đụng tới" do
    enr = enrollment(expires_on: 6.months.from_now.to_date, used: 1)
    CourseMaintenanceJob.new.perform
    assert_equal "active", with_tenant(@ws) { enr.reload.status }
  end
end
