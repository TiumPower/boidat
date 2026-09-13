require "test_helper"

# Điểm danh và trừ buổi — nơi tiền và niềm tin của phụ huynh gặp nhau.
class AttendanceTest < ActiveSupport::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      @course.ensure_session_plan!
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                                 class_type: 2, start_hour: 17, weekdays: [1, 3],
                                 start_date: 2.weeks.ago.to_date.beginning_of_week, status: "running")
      LessonGenerator.new(@class).call
      @enrollment = Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student,
                                       swim_class: @class, sessions_total: 12, status: "active")
      @lesson = @class.lessons.order(:session_index).first
    end
  end

  test "điểm danh thành công trừ đúng một buổi" do
    with_tenant(@ws) do
      result = AttendanceRecorder.new(lesson: @lesson, student: @c.student, actor: @c.users[:receptionist],
                                      method: "face", face_score: 0.98).check_in!
      assert result.ok?
      assert_equal 1, @enrollment.reload.sessions_used
      assert_equal 11, @enrollment.sessions_left
      assert @lesson.attendances.first.deducted
    end
  end

  test "điểm danh hai lần không trừ hai buổi" do
    with_tenant(@ws) do
      AttendanceRecorder.new(lesson: @lesson, student: @c.student).check_in!
      second = AttendanceRecorder.new(lesson: @lesson, student: @c.student).check_in!
      refute second.ok?
      assert_equal 1, @enrollment.reload.sessions_used
    end
  end

  test "bỏ điểm danh thì hoàn lại buổi" do
    with_tenant(@ws) do
      AttendanceRecorder.new(lesson: @lesson, student: @c.student).check_in!
      AttendanceRecorder.new(lesson: @lesson, student: @c.student).undo!
      assert_equal 0, @enrollment.reload.sessions_used
      assert_equal 0, @lesson.attendances.count
    end
  end

  test "hết buổi thì không điểm danh được nữa" do
    with_tenant(@ws) do
      @enrollment.update!(sessions_used: 12)
      result = AttendanceRecorder.new(lesson: @lesson, student: @c.student).check_in!
      refute result.ok?
      assert_match "hết buổi", result.message
    end
  end

  test "vắng không báo thì không trừ buổi (BR-12)" do
    with_tenant(@ws) do
      # Không có bản ghi điểm danh nào = học viên không đến. Số buổi giữ nguyên.
      assert_equal 0, @enrollment.reload.sessions_used
      refute @ws.no_show_deducts?
    end
  end

  test "OQ-25: cả 12 buổi đều là buổi học và đều bị trừ khỏi gói" do
    with_tenant(@ws) do
      assert_equal 0, @class.lessons.where(exam: true).count,
                   "kỳ thi xếp riêng nên không buổi nào trong khoá là buổi thi"
      last = @class.lessons.order(:session_index).last
      @enrollment.update!(sessions_used: 11)
      result = AttendanceRecorder.new(lesson: last, student: @c.student).check_in!
      assert result.ok?
      assert_equal 12, @enrollment.reload.sessions_used, "buổi 12 là buổi học nên vẫn trừ"
      assert last.attendances.first.deducted
    end
  end

  test "trung tâm nào gộp buổi thi vào khoá thì buổi đó không trừ gói" do
    with_tenant(@ws) do
      @ws.update_business_settings!("exam_session_index" => 12)
      exam_lesson = @class.lessons.order(:session_index).last
      exam_lesson.update!(exam: true)
      @enrollment.update!(sessions_used: 11)

      AttendanceRecorder.new(lesson: exam_lesson, student: @c.student).check_in!
      assert_equal 11, @ws.reload && @enrollment.reload.sessions_used
      refute exam_lesson.attendances.first.deducted
    end
  end

  test "học đủ mốc thì vào danh sách thi và không rớt ra (OQ-07)" do
    with_tenant(@ws) do
      target = @ws.graduation_at_session
      @enrollment.update!(sessions_used: target - 1)
      AttendanceRecorder.new(lesson: @lesson, student: @c.student).check_in!

      assert_equal target, @enrollment.reload.sessions_used
      assert @enrollment.exam_eligible_at.present?, "phải được gắn cờ đủ điều kiện thi"

      # Học thêm một buổi nữa vẫn còn trong danh sách nhờ cờ dính.
      @enrollment.update!(sessions_used: target + 1)
      assert @enrollment.exam_eligible?
    end
  end

  test "học viên không có đăng ký ở lớp thì không điểm danh được" do
    with_tenant(@ws) do
      other = create(:student, workspace: @ws, household: @c.household, pool: @pool, name: "Bé lạ")
      result = AttendanceRecorder.new(lesson: @lesson, student: other).check_in!
      refute result.ok?
      assert_match "không có đăng ký", result.message
    end
  end
end
