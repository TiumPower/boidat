require "test_helper"

# PWA giáo viên (S4): lịch dạy, giáo án, nhận xét, bảng công, xin nghỉ.
class TeacherPortalTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      @course.ensure_session_plan!
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                                 class_type: 2, start_hour: 17, weekdays: [Date.current.wday],
                                 start_date: Date.current, status: "running")
      LessonGenerator.new(@class).call(total: 4)
      Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student, swim_class: @class,
                         sessions_total: 12, status: "active")
      @lesson = @class.lessons.find_by(date: Date.current)
    end
    host_workspace!(@ws)
    sign_in @c.users[:teacher]
  end

  test "lịch dạy hôm nay hiện buổi và học viên" do
    get "/teacher"
    assert_response :success
    assert_match @c.student.short_name, response.body
    assert_match "17:00", response.body
  end

  test "slot đã đăng ký dạy nhưng chưa có lớp hiện là slot trống" do
    with_tenant(@ws) do
      TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: @pool,
                                  month: Date.current.beginning_of_month, weekday: Date.current.wday,
                                  hour: 19, submitted_at: Time.current)
    end
    get "/teacher"
    assert_response :success
    assert_match "Slot trống", response.body
    assert_match "19:00", response.body
  end

  test "sửa giáo án chỉ áp cho buổi đó, không đụng giáo án gốc của khoá" do
    original = with_tenant(@ws) { @course.plan_for(1).content }
    patch "/teacher/lessons/#{@lesson.id}", params: { content_override: "Hôm nay tập thở nghiêng 3×15m" }
    with_tenant(@ws) do
      assert_equal "Hôm nay tập thở nghiêng 3×15m", @lesson.reload.content
      assert_equal original, @course.plan_for(1).reload.content, "giáo án gốc không đổi"
    end
  end

  test "gửi nhận xét thì phụ huynh nhận được thông báo" do
    post "/teacher/lessons/#{@lesson.id}/feedbacks", params: {
      feedbacks: { @c.student.id.to_s => { tag: "progress", body: "Ngọc đã thở nghiêng được 15m." } }
    }
    assert_redirected_to teacher_lesson_path(@lesson)
    with_tenant(@ws) do
      fb = SessionFeedback.find_by(lesson: @lesson, student: @c.student)
      assert fb
      assert_equal "progress", fb.tag
      note = Notification.find_by(recipient: @c.guardian, kind: "feedback")
      assert note, "phụ huynh phải nhận được thông báo có nhận xét mới"
    end
  end

  test "bảng công hiện công tính từ điểm danh, không nhập tay" do
    with_tenant(@ws) do
      # Lớp 1:2 có hai học viên đăng ký, hôm nay chỉ một em đến.
      second = create(:student, workspace: @ws, household: @c.household, pool: @pool, name: "Bé thứ hai")
      Enrollment.create!(workspace: @ws, pool: @pool, student: second, swim_class: @class,
                         sessions_total: 12, status: "active")
      AttendanceRecorder.new(lesson: @lesson, student: @c.student).check_in!
    end
    get "/teacher/timesheet", params: { range: "month" }
    assert_response :success
    with_tenant(@ws) do
      entry = @lesson.reload.timesheet_entry
      assert entry, "phải có dòng công sau khi điểm danh"
      assert_equal 1.0, entry.credits.to_f,
                   "tính theo sĩ số đăng ký (OQ-06): 2 em đăng ký → 1.0 công dù chỉ 1 em đến"
    end
  end

  test "đăng ký lịch dạy tháng ghi đè lựa chọn cũ" do
    month = Date.current.next_month.beginning_of_month
    patch "/teacher/availability", params: {
      month: month.strftime("%Y-%m"),
      slots: ["#{@pool.id}:1:17", "#{@pool.id}:3:17", "#{@pool.id}:5:18"]
    }
    with_tenant(@ws) do
      assert_equal 3, TeacherAvailability.for_month(month).where(teacher: @c.teacher).count
    end

    patch "/teacher/availability", params: { month: month.strftime("%Y-%m"), slots: ["#{@pool.id}:1:17"] }
    with_tenant(@ws) do
      assert_equal 1, TeacherAvailability.for_month(month).where(teacher: @c.teacher).count
    end
  end

  test "gửi đơn xin nghỉ thì admin nhận thông báo" do
    post "/teacher/leaves", params: { lesson_ids: [@lesson.id], reason: "Việc gia đình" }
    assert_redirected_to teacher_leave_requests_path
    with_tenant(@ws) do
      req = LeaveRequest.last
      assert_equal [@lesson.id], req.lesson_ids
      assert_equal "pending", req.status
      assert Notification.where(recipient: @c.users[:admin], kind: "teacher_leave").exists?
    end
  end

  test "giáo viên chỉ thấy buổi của chính mình" do
    other = with_tenant(@ws) do
      u = create(:user)
      Membership.create!(user: u, workspace: @ws, role: "teacher")
      t = Teacher.create!(workspace: @ws, user: u, teacher_level: @c.teacher.teacher_level, kind: "staff")
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: t, class_type: 1, start_hour: 8,
                              weekdays: [Date.current.wday], start_date: Date.current, status: "running")
      LessonGenerator.new(cls).call(total: 2)
      cls.lessons.first
    end
    get "/teacher/lessons/#{other.id}"
    assert_response :not_found
  end
end
