require "test_helper"

# FR-204 — một thao tác của sale phải sinh trọn bộ dữ liệu. Đây là luồng dễ để
# sót nhất: có học viên mà không có lớp, hoặc có lớp mà không có đơn hàng.
class RegistrationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @course = Course.create!(workspace: @ws, name: "Bơi cơ bản trẻ em")
      @course.ensure_session_plan!
      @package = Package.create!(workspace: @ws, name: "Khoá 12 buổi 1:2", kind: "full_course",
                                 course: @course, class_type: 2, sessions: 12)
      PriceListItem.create!(workspace: @ws, package: @package, price: 4_800_000)
    end
    host_workspace!(@ws)
    sign_in @c.users[:sale]
  end

  def valid_params(overrides = {})
    { registration: {
        student_name: "Nguyễn Gia Bảo", birthdate: 6.years.ago.to_date.to_s, gender: "nam",
        health_notes: "Hen suyễn nhẹ", source: "Giới thiệu",
        guardian_name: "Nguyễn Văn Hùng", guardian_phone: "0908221447", guardian_relation: "Bố",
        teacher_id: @c.teacher.id, start_hour: 17, class_type: 2,
        weekday_list: "1,3", start_date: Date.current.next_week.to_s,
        course_id: @course.id, package_id: @package.id, customer_type: "new"
      }.merge(overrides) }
  end

  test "một lần submit sinh đủ học viên, hộ, QR, lớp, buổi, đăng ký, đơn hàng và thông báo" do
    assert_difference -> { with_tenant(@ws) { Student.count } }, 1 do
      assert_difference -> { with_tenant(@ws) { SwimClass.count } }, 1 do
        assert_difference -> { with_tenant(@ws) { Order.count } }, 1 do
          post "/merchant/ops/registrations", params: valid_params
        end
      end
    end
    assert_response :redirect

    with_tenant(@ws) do
      student = Student.find_by(name: "Nguyễn Gia Bảo")
      assert student, "chưa tạo học viên"
      assert_equal @pool.id, student.pool_id, "học viên phải khoá theo hồ đang trực"
      assert student.household.qr_token.present?, "hộ gia đình phải có mã QR"
      assert_equal "Nguyễn Văn Hùng", student.household.owner.name

      cls = student.swim_classes.first
      assert_equal [1, 3], cls.weekday_list
      assert_equal 12, cls.lessons.count, "phải sinh đủ 12 buổi"

      enrollment = student.enrollments.first
      assert_equal 12, enrollment.sessions_total
      assert_equal Date.current.next_week + @ws.package_validity_days, enrollment.expires_on

      order = Order.last
      assert_equal 4_800_000, order.amount
      assert_equal "unpaid", order.status
      assert_equal @c.users[:sale].id, order.sale_id
    end
  end

  test "thông báo bắn cho CẢ giáo viên lẫn phụ huynh ngay khi tạo lớp (FR-222)" do
    post "/merchant/ops/registrations", params: valid_params
    with_tenant(@ws) do
      teacher_note = Notification.find_by(recipient: @c.teacher.user, kind: "class_created")
      assert teacher_note, "giáo viên phải nhận được thông báo có học viên mới"
      assert_match "Nguyễn Gia Bảo", teacher_note.body

      guardian = Guardian.find_by(name: "Nguyễn Văn Hùng")
      parent_note = Notification.find_by(recipient: guardian, kind: "class_created")
      assert parent_note, "phụ huynh phải nhận được thông báo đăng ký thành công"
      assert_match "buổi", parent_note.body
    end
  end

  test "trẻ em mà thiếu thông tin phụ huynh thì không cho submit" do
    post "/merchant/ops/registrations",
         params: valid_params.deep_merge(registration: { guardian_name: "" })
    assert_response :unprocessable_entity
    assert_match "cần thông tin phụ huynh", response.body
  end

  test "người lớn tự học không cần phụ huynh" do
    post "/merchant/ops/registrations", params: valid_params.deep_merge(
      registration: { student_name: "Phạm Quốc Duy", guardian_name: "", adult_self_study: "1",
                      birthdate: 30.years.ago.to_date.to_s }
    )
    assert_response :redirect
    with_tenant(@ws) do
      student = Student.find_by(name: "Phạm Quốc Duy")
      assert student
      assert_equal "individual", student.household.kind
    end
  end

  test "thêm con thứ hai vào hộ đã có thì dùng chung mã QR" do
    post "/merchant/ops/registrations", params: valid_params
    with_tenant(@ws) do
      household = Student.find_by(name: "Nguyễn Gia Bảo").household
      post "/merchant/ops/registrations", params: valid_params.deep_merge(
        registration: { student_name: "Trần Bảo Ngọc", household_id: household.id }
      )
      second = Student.find_by(name: "Trần Bảo Ngọc")
      assert_equal household.id, second.household_id
      assert_equal 2, household.students.count
    end
  end

  test "đăng ký vào slot đã có lớp thì vào lớp đó, không mở lớp trùng giờ" do
    post "/merchant/ops/registrations", params: valid_params
    first_class = with_tenant(@ws) { Student.find_by(name: "Nguyễn Gia Bảo").enrollments.first.swim_class }

    assert_no_difference -> { with_tenant(@ws) { SwimClass.count } } do
      post "/merchant/ops/registrations", params: valid_params.deep_merge(
        registration: { student_name: "Lâm Khánh Vy", guardian_name: "Lâm Quốc Cường",
                        guardian_phone: "0908221448" }
      )
    end
    assert_response :redirect
    with_tenant(@ws) do
      second = Student.find_by(name: "Lâm Khánh Vy")
      assert_equal first_class.id, second.enrollments.first.swim_class_id,
                   "phải vào đúng lớp đang chạy ở khung giờ đó"
    end
  end

  test "lớp nhóm hết chỗ thì báo rõ chứ không nhét thêm" do
    post "/merchant/ops/registrations", params: valid_params
    cls = with_tenant(@ws) { SwimClass.last }
    2.times do |i|
      post "/merchant/ops/registrations", params: valid_params.deep_merge(
        registration: { student_name: "Bé #{i}", swim_class_id: cls.id }
      )
    end
    assert_response :unprocessable_entity
    assert_match "đã đủ", response.body
    assert_equal cls.capacity, with_tenant(@ws) { cls.reload.seats_taken }
  end

  test "giá lấy từ bảng giá của hồ tại thời điểm bán" do
    with_tenant(@ws) do
      PriceListItem.create!(workspace: @ws, package: @package, pool: @pool, price: 5_200_000)
    end
    post "/merchant/ops/registrations", params: valid_params
    assert_equal 5_200_000, with_tenant(@ws) { Order.last.amount }
  end
end
