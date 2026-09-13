require "test_helper"

# Sinh buổi học, sức chứa lớp và quy tắc trừ buổi.
class SchedulingTest < ActiveSupport::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
  end

  def make_class(weekdays: [1, 3], hour: 17, class_type: 2, start_date: Date.current.next_week)
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      course.ensure_session_plan!
      SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: course,
                        class_type: class_type, start_hour: hour, weekdays: weekdays,
                        start_date: start_date, status: "running")
    end
  end

  test "sinh đủ số buổi của khoá theo khung lặp" do
    cls = make_class
    with_tenant(@ws) do
      LessonGenerator.new(cls).call
      assert_equal cls.total_sessions, cls.lessons.count
      assert cls.lessons.all? { |l| [1, 3].include?(l.date.wday) }, "buổi phải rơi đúng T2/T4"
      assert_equal (1..cls.total_sessions).to_a, cls.lessons.order(:session_index).pluck(:session_index)
    end
  end

  test "buổi cuối được đánh dấu là buổi thi" do
    cls = make_class
    with_tenant(@ws) do
      LessonGenerator.new(cls).call
      exam = cls.lessons.find_by(session_index: cls.course.exam_session)
      assert exam.exam?
    end
  end

  test "không sinh buổi vào ngày hồ đóng cửa" do
    with_tenant(@ws) do
      # Đóng cửa thứ 4 → khung T2 & T4 chỉ còn rơi vào T2.
      @pool.operating_hours.find_by(weekday: 3).update!(closed: true)
      cls = make_class
      LessonGenerator.new(cls.reload).call
      assert cls.lessons.none? { |l| l.date.wday == 3 }, "không được sinh buổi vào ngày hồ đóng"
    end
  end

  test "ngày nghỉ lễ bị bỏ qua, buổi dồn sang lần lặp sau" do
    with_tenant(@ws) do
      cls = make_class
      first_monday = (cls.start_date..(cls.start_date + 14)).find { |d| d.wday == 1 }
      PoolHoliday.create!(workspace: @ws, pool: @pool, date: first_monday, reason: "Bảo trì")
      LessonGenerator.new(cls).call
      refute_includes cls.lessons.pluck(:date), first_monday
      assert_equal cls.total_sessions, cls.lessons.count, "vẫn phải đủ số buổi"
    end
  end

  test "sinh lại không tạo trùng và không đụng buổi đã có" do
    cls = make_class
    with_tenant(@ws) do
      LessonGenerator.new(cls).call
      assert_no_difference -> { cls.lessons.count } do
        LessonGenerator.new(cls.reload).call
      end
    end
  end

  test "đổi lịch chỉ dời buổi chưa diễn ra" do
    cls = make_class(start_date: 4.weeks.ago.to_date.beginning_of_week)
    with_tenant(@ws) do
      LessonGenerator.new(cls).call
      past = cls.lessons.where("date < ?", Date.current).to_a
      past_ids = past.map(&:id)
      assert past.any?, "phải có buổi trong quá khứ để test"

      LessonGenerator.new(cls).reschedule_future!(weekdays: [5], start_hour: 19)
      assert_equal past_ids.sort, cls.lessons.where("date < ?", Date.current).pluck(:id).sort,
                   "buổi đã diễn ra không được đụng vào"
      future = cls.lessons.where("date >= ?", Date.current)
      assert future.all? { |l| l.date.wday == 5 && l.start_hour == 19 }
    end
  end

  test "sức chứa lớp không vượt quá level của giáo viên" do
    with_tenant(@ws) do
      @c.teacher.teacher_level.update!(max_students_per_slot: 2)
      cls = SwimClass.new(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 4,
                          start_hour: 17, weekdays: [1], start_date: Date.current)
      refute cls.valid?
      assert_match "vượt sức chứa", cls.errors.full_messages.join
    end
  end
end
