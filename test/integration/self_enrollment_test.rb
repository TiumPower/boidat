require "test_helper"

# Học viên CŨ tự đăng ký khoá mới trên PWA — không phải gọi sale.
class SelfEnrollmentTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      @course.ensure_session_plan!
      @pkg_1v2 = Package.create!(workspace: @ws, name: "Khoá 12 buổi 1:2", kind: "full_course",
                                 course: @course, class_type: 2, sessions: 12)
      PriceListItem.create!(workspace: @ws, package: @pkg_1v2, price: 4_800_000)
      @pkg_1v1 = Package.create!(workspace: @ws, name: "Khoá 12 buổi 1:1", kind: "full_course",
                                 course: @course, class_type: 1, sessions: 12)
      PriceListItem.create!(workspace: @ws, package: @pkg_1v1, price: 9_600_000)

      # Khoá cũ sắp hết buổi — đúng lúc phụ huynh muốn tái ký.
      old_class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                                    class_type: 2, start_hour: 17, weekdays: [1],
                                    start_date: 10.weeks.ago.to_date, status: "running")
      Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student, swim_class: old_class,
                         sessions_total: 12, sessions_used: 11, status: "active")

      # Khung giáo viên đã đăng ký dạy nhưng chưa có lớp.
      [18, 19].each do |hour|
        [Date.current.beginning_of_month, Date.current.next_month.beginning_of_month].each do |m|
          TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: @pool,
                                      month: m, weekday: 3, hour: hour, submitted_at: Time.current)
        end
      end
    end
    host! "#{@ws.subdomain}.example.com"
    get "/q/#{@c.household.qr_token}"
  end

  test "phụ huynh thấy nút đăng ký khoá mới khi con sắp hết buổi" do
    get "/students/#{@c.student.id}"
    assert_response :success
    assert_match "Sắp hết buổi — đăng ký khoá mới", response.body
  end

  test "màn hình tái ký hiện gói và khung giờ còn trống" do
    get "/students/#{@c.student.id}/enroll"
    assert_response :success
    assert_match "Khoá 12 buổi 1:2", response.body
    assert_match "18:00", response.body
    assert_match @c.teacher.short_name, response.body
  end

  test "tự đăng ký mở lớp mới, sinh đơn chờ thanh toán và báo cho trung tâm" do
    slot = "#{@c.teacher.id}:3:18"
    assert_difference -> { with_tenant(@ws) { Order.count } }, 1 do
      post "/students/#{@c.student.id}/enroll", params: { package_id: @pkg_1v2.id, slot: slot }
    end
    assert_response :redirect

    with_tenant(@ws) do
      enrollment = Enrollment.order(:created_at).last
      assert_equal @c.student.id, enrollment.student_id, "phải dùng lại học viên cũ, không tạo hồ sơ mới"
      assert_equal "returning", enrollment.customer_type
      assert_equal 2, enrollment.swim_class.class_type
      assert_equal 18, enrollment.swim_class.start_hour
      assert enrollment.swim_class.lessons.count.positive?, "phải sinh buổi học"

      order = Order.order(:created_at).last
      assert_equal "renewal", order.kind
      assert_equal "unpaid", order.status
      assert_equal 4_800_000, order.amount

      assert Notification.where(recipient: @c.users[:admin], kind: "class_created").exists?,
             "admin của hồ phải được báo có khách tự tái ký"
      assert Notification.where(recipient: @c.teacher.user, kind: "class_created").exists?
    end
  end

  test "không tạo thêm học viên trùng tên khi tái ký" do
    assert_no_difference -> { with_tenant(@ws) { Student.count } } do
      post "/students/#{@c.student.id}/enroll",
           params: { package_id: @pkg_1v2.id, slot: "#{@c.teacher.id}:3:18" }
    end
  end

  test "gói quyết định loại lớp — mua gói 1:1 thì mở lớp 1:1" do
    post "/students/#{@c.student.id}/enroll",
         params: { package_id: @pkg_1v1.id, slot: "#{@c.teacher.id}:3:19" }
    with_tenant(@ws) do
      assert_equal 1, Enrollment.order(:created_at).last.swim_class.class_type,
                   "không được mở lớp 1:2 khi khách trả tiền gói 1:1"
    end
  end

  test "chọn lớp nhóm không khớp loại gói thì bị chặn" do
    group_class = with_tenant(@ws) do
      SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                        class_type: 3, start_hour: 20, weekdays: [4],
                        start_date: 1.week.from_now.to_date, status: "running")
    end
    post "/students/#{@c.student.id}/enroll",
         params: { package_id: @pkg_1v1.id, swim_class_id: group_class.id }
    assert_response :unprocessable_entity
    assert_match "không khớp lớp 1:3", response.body
  end

  test "vào lớp nhóm còn chỗ thì không mở lớp mới" do
    group_class = with_tenant(@ws) do
      SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                        class_type: 2, start_hour: 20, weekdays: [4],
                        start_date: 1.week.from_now.to_date, status: "running")
    end
    assert_no_difference -> { with_tenant(@ws) { SwimClass.count } } do
      post "/students/#{@c.student.id}/enroll",
           params: { package_id: @pkg_1v2.id, swim_class_id: group_class.id }
    end
    with_tenant(@ws) { assert_equal group_class.id, Enrollment.order(:created_at).last.swim_class_id }
  end

  test "người đưa đón không được tự đăng ký khoá (phát sinh tiền)" do
    pickup = with_tenant(@ws) do
      @c.household.guardians.destroy_all
      create(:guardian, workspace: @ws, household: @c.household, role: "pickup")
    end
    get "/q/#{@c.household.reload.qr_token}"
    get "/students/#{@c.student.id}/enroll"
    assert_redirected_to "/"
    assert_match "Chỉ chủ gia đình", flash[:alert]
    assert pickup.pickup?
  end

  test "không đăng ký hộ học viên của gia đình khác" do
    other = with_tenant(@ws) do
      hh = create(:household, workspace: @ws)
      create(:student, workspace: @ws, household: hh, pool: @pool, name: "Bé nhà khác")
    end
    get "/students/#{other.id}/enroll"
    assert_response :not_found
  end
end
