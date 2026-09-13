require "test_helper"

# Lớp dạy hết giáo trình vẫn nằm ở status "running" cho tới khi có người đóng.
# Trước đây không ai đóng cả, và hậu quả không phải chuyện thẩm mỹ:
#
#   1. Bộ xếp lịch coi khung giờ của lớp đã xong là vùng cấm (FR-205 khoá cứng
#      lớp đang chạy), nên khung ấy vĩnh viễn không xếp lại được ai. Trên
#      production đã có lúc 6/16 khung của Hồ Quận 7 chết theo kiểu này.
#   2. Cổng phụ huynh vẫn chào bán chỗ trống của lớp không còn buổi nào để học —
#      phụ huynh trả tiền cho một khoá đã kết thúc.
class FinishedClassTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
  end

  # Lớp đã dạy xong: mọi buổi đều ở quá khứ.
  def finished_class!(hour: 17, weekday: 1)
    with_tenant(@ws) do
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                              start_hour: hour, weekdays: [weekday],
                              start_date: 20.weeks.ago.to_date.beginning_of_week, status: "running")
      LessonGenerator.new(cls).call(total: 12)
      cls.lessons.update_all(status: "done")
      cls
    end
  end

  test "lớp đã dạy hết không còn nằm trong phạm vi đang dạy" do
    cls = finished_class!
    with_tenant(@ws) do
      assert cls.running?, "status vẫn là running cho tới khi job đóng nó"
      assert cls.course_over?
      refute_includes SwimClass.teaching.pluck(:id), cls.id
    end
  end

  test "lớp chưa sinh buổi nào thì KHÔNG bị coi là đã xong" do
    with_tenant(@ws) do
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                              start_hour: 9, weekdays: [2], start_date: Date.current, status: "running")
      refute cls.course_over?, "lớp mới tạo chỉ là chưa bắt đầu, không phải đã kết thúc"
      assert_includes SwimClass.teaching.pluck(:id), cls.id,
                      "nghi ngờ thì phải giữ chỗ, nếu không bộ xếp lịch sẽ xếp đè lên giáo viên"
    end
  end

  test "khung giờ của lớp đã xong được giải phóng cho bộ xếp lịch" do
    cls = finished_class!(hour: 17, weekday: 1)
    month = Date.current.next_month.beginning_of_month
    with_tenant(@ws) do
      TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: @pool,
                                  month: month, weekday: 1, hour: 17, submitted_at: Time.current)
      run = AutoScheduler.new(pool: @pool, month: month, workspace: @ws).build_draft
      assert_equal [17], run.proposal_rows.map { |r| r[:hour] },
                   "lớp #{cls.code} đã dạy xong thì khung 17h phải xếp lại được"
    end
  end

  test "phụ huynh không được mời vào lớp đã dạy xong" do
    cls = finished_class!(hour: 8, weekday: 3)
    with_tenant(@ws) do
      opts = SelfEnrollmentOptions.new(student: @c.student, pool: @pool)
      refute_includes opts.open_classes.map { |s| s.swim_class.id }, cls.id
    end
  end

  test "job bảo trì đóng lớp đã dạy xong và không đụng lớp đang chạy" do
    done = finished_class!(hour: 17, weekday: 1)
    live = with_tenant(@ws) do
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                              start_hour: 19, weekdays: [4], start_date: 1.week.ago.to_date, status: "running")
      LessonGenerator.new(cls).call(total: 12)
      cls
    end

    CourseMaintenanceJob.new.perform

    assert_equal "finished", done.reload.status
    assert_equal "running", live.reload.status
  end
end
