require "test_helper"

# Quầy điểm danh (S3) — ngoại lệ FR-235 là chỗ dễ rò rỉ dữ liệu nhất trong cả hệ
# thống, nên phải khoá bằng test.
class DeskAttendanceTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    @other_pool = @c.pools.last
    with_tenant(@ws) do
      @course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      @course.ensure_session_plan!
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                                 class_type: 2, start_hour: 17, weekdays: [Date.current.wday],
                                 start_date: Date.current, status: "running")
      LessonGenerator.new(@class).call(total: 4)
      @enrollment = Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student,
                                       swim_class: @class, sessions_total: 12, status: "active")
      @lesson = @class.lessons.find_by(date: Date.current)

      # Học viên của hồ khác — dùng để kiểm tra ngoại lệ FR-235.
      hh = create(:household, workspace: @ws, name: "Hộ hồ Thủ Đức")
      create(:guardian, workspace: @ws, household: hh)
      @foreign = create(:student, workspace: @ws, household: hh, pool: @other_pool, name: "Lê Minh Khang")
    end
    host_workspace!(@ws)
    sign_in @c.users[:receptionist]
  end

  test "tra cứu chạy trên học viên của mọi hồ (FR-235)" do
    get "/desk/scan", params: { q: "Lê Minh" }
    assert_response :success
    assert_match "Lê Minh Khang", response.body, "quét ở quầy nào cũng phải tra ra"
    assert_match @other_pool.name, response.body, "phải hiện luôn hồ trực thuộc"
  end

  test "học viên hồ khác bị chặn điểm danh và chỉ lộ thông tin tối thiểu" do
    get "/desk/scan", params: { student_id: @foreign.id }
    assert_response :success
    assert_match "thuộc cơ sở", response.body
    assert_match @foreign.name, response.body
    refute_match "Buổi hôm nay", response.body, "không được lộ lịch học của hồ khác"
    refute_match "Còn lại sau buổi này", response.body

    post "/desk/scan", params: { student_id: @foreign.id }
    assert_redirected_to desk_scan_path(student_id: @foreign.id)
    with_tenant(@ws) { assert_equal 0, Attendance.where(student: @foreign, status: "present").count }
  end

  test "xác nhận điểm danh thì trừ đúng một buổi" do
    post "/desk/scan", params: { student_id: @c.student.id }
    assert_redirected_to desk_root_path
    with_tenant(@ws) do
      assert_equal 1, @enrollment.reload.sessions_used
      att = @lesson.attendances.find_by(student: @c.student)
      assert att.present?
      assert att.deducted
      assert_equal @c.users[:receptionist].id, att.actor_id
    end
  end

  test "không có lịch hôm nay thì không cho điểm danh" do
    with_tenant(@ws) { @lesson.update!(date: 3.days.from_now) }
    post "/desk/scan", params: { student_id: @c.student.id }
    assert_match "không có buổi học", flash[:alert]
  end

  test "hết hạn gói thì chặn ngay ở quầy" do
    with_tenant(@ws) { @enrollment.update!(expires_on: 1.day.ago) }
    post "/desk/scan", params: { student_id: @c.student.id }
    assert_match "hết hạn", flash[:alert]
  end

  test "vé lẻ dùng mã QR một lần, dùng lần hai bị chặn" do
    ticket = with_tenant(@ws) do
      DayPassTicket.create!(workspace: @ws, pool: @pool, quantity: 2, valid_on: Date.current)
    end
    post "/desk/scan/ticket", params: { code: ticket.code }
    assert_match "Đã ghi nhận vé", flash[:notice]

    post "/desk/scan/ticket", params: { code: ticket.code }
    assert_match "đã dùng", flash[:alert].downcase
  end

  test "vé của hồ khác không dùng được ở đây" do
    ticket = with_tenant(@ws) do
      DayPassTicket.create!(workspace: @ws, pool: @other_pool, valid_on: Date.current)
    end
    post "/desk/scan/ticket", params: { code: ticket.code }
    assert_match "không dùng ở đây được", flash[:alert]
  end

  test "trang ca trực hiện đúng số liệu trong ngày" do
    post "/desk/scan", params: { student_id: @c.student.id }
    get "/desk"
    assert_response :success
    assert_match @c.student.name, response.body
    assert_match "Đã trừ buổi", response.body
  end
end
