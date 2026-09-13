require "test_helper"

# Bảng master data (FR-202/203): phải hiện CẢ slot đã có lớp lẫn slot còn trống,
# và slot trống chỉ xuất hiện khi giáo viên đã đăng ký dạy khung đó.
class ScheduleBoardTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    @monday = Date.current.next_week
    with_tenant(@ws) do
      # Giáo viên đăng ký dạy T2 lúc 17h và 18h.
      [17, 18].each do |hour|
        TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: @pool,
                                    month: @monday.beginning_of_month, weekday: 1, hour: hour,
                                    submitted_at: Time.current)
      end
      # Một lớp đã chiếm khung 17h.
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                                 start_hour: 17, weekdays: [1], start_date: @monday, status: "running")
      LessonGenerator.new(@class).call(total: 4)
      Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student, swim_class: @class,
                         sessions_total: 12, status: "active")
    end
    host_workspace!(@ws)
    sign_in @c.users[:sale]
  end

  test "bảng hiện cả slot đã có lớp lẫn slot trống" do
    board = with_tenant(@ws) { ScheduleBoard.new(pool: @pool, days: [@monday]) }
    hours = board.slots.map(&:hour).sort
    assert_equal [17, 18], hours
    assert_equal 1, board.booked_slots.size
    assert_equal 1, board.free_slots.size
    assert_equal 18, board.free_slots.first.hour, "18h là khung đã đăng ký nhưng chưa có học viên"
  end

  test "giáo viên chưa đăng ký lịch thì không sinh slot trống" do
    with_tenant(@ws) do
      TeacherAvailability.where(teacher: @c.teacher).destroy_all
      board = ScheduleBoard.new(pool: @pool, days: [@monday])
      assert_equal 0, board.free_slots.size
      assert_equal 1, board.booked_slots.size, "buổi đã có vẫn phải hiện"
    end
  end

  test "màn hình lịch chạy được với cả ba chế độ xem" do
    %w[day week month].each do |view|
      get "/merchant/ops", params: { view: view, date: @monday.to_s }
      assert_response :success, "chế độ #{view} lỗi"
    end
  end

  test "lọc chỉ slot trống" do
    get "/merchant/ops", params: { view: "day", date: @monday.to_s, free: "1" }
    assert_response :success
    assert_match "Slot trống", response.body
    refute_match @c.student.short_name, response.body
  end

  test "tìm theo tên giáo viên ra lịch của giáo viên đó" do
    get "/merchant/ops", params: { view: "week", date: @monday.to_s, q: @c.teacher.name }
    assert_response :success
    assert_match @c.teacher.short_name, response.body
  end

  test "điểm danh tay ngay trên bảng master data (FR-234)" do
    lesson = with_tenant(@ws) { @class.lessons.order(:session_index).first }
    patch "/merchant/ops/lessons/#{lesson.id}/attend", params: { student_id: @c.student.id }
    assert_response :redirect
    with_tenant(@ws) do
      assert_equal 1, lesson.attendances.count
      assert_equal "manual", lesson.attendances.first.method
      assert_equal 1, Enrollment.find_by(student: @c.student).sessions_used
      # Mọi lần sửa tay đều vào nhật ký để đối chiếu khi có tranh chấp.
      assert AuditLog.recent.first.summary.include?("Điểm danh tay")
    end
  end

  test "slot của hồ khác không lọt vào bảng" do
    with_tenant(@ws) do
      other_pool = @c.pools.last
      TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: other_pool,
                                  month: @monday.beginning_of_month, weekday: 1, hour: 19)
      board = ScheduleBoard.new(pool: @pool, days: [@monday])
      refute_includes board.slots.map(&:hour), 19
    end
  end
end
