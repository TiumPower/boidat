require "test_helper"

# Chấm công — nơi khách hàng dễ khiếu nại nhất, nên quy tắc phải khoá bằng test.
class PayrollTest < ActiveSupport::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @c.teacher.teacher_level.update!(max_students_per_slot: 4, pay_rate_per_credit: 90_000)
      @course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      @course.ensure_session_plan!
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                                 class_type: 3, start_hour: 17, weekdays: [1, 3],
                                 start_date: 1.week.ago.to_date.beginning_of_week, status: "running")
      LessonGenerator.new(@class).call
      @lesson = @class.lessons.order(:session_index).first
      @students = 3.times.map do |i|
        st = create(:student, workspace: @ws, household: @c.household, pool: @pool, name: "Bé #{i}")
        Enrollment.create!(workspace: @ws, pool: @pool, student: st, swim_class: @class,
                           sessions_total: 12, status: "active")
        st
      end
    end
  end

  test "công = 0.5 × số học viên CÓ MẶT × đơn giá cấp độ (BR-02, OQ-06)" do
    with_tenant(@ws) do
      @students.each { |st| AttendanceRecorder.new(lesson: @lesson, student: st).check_in! }
      entry = @lesson.reload.timesheet_entry
      assert_equal 3, entry.headcount
      assert_equal 1.5, entry.credits.to_f, "3 em có mặt = 1.5 công"
      assert_equal 135_000, entry.amount, "1.5 công × 90.000đ"
      assert_equal "present", entry.basis
    end
  end

  test "học viên vắng thì giáo viên không được tính công cho suất đó (OQ-06)" do
    with_tenant(@ws) do
      # Lớp 1:3 nhưng chỉ một em tới.
      AttendanceRecorder.new(lesson: @lesson, student: @students.first).check_in!
      entry = @lesson.reload.timesheet_entry
      assert_equal 1, entry.headcount
      assert_equal 0.5, entry.credits.to_f, "chỉ tính suất của em đã đến"
    end
  end

  test "công cộng dồn theo từng lượt điểm danh" do
    with_tenant(@ws) do
      AttendanceRecorder.new(lesson: @lesson, student: @students.first).check_in!
      assert_equal 0.5, @lesson.reload.timesheet_entry.credits.to_f
      AttendanceRecorder.new(lesson: @lesson, student: @students.second).check_in!
      assert_equal 1.0, @lesson.reload.timesheet_entry.credits.to_f
    end
  end

  test "không ai đến thì không phát sinh dòng công nào" do
    with_tenant(@ws) do
      assert_nil PayrollCalculator.new(@lesson).call
      assert_nil @lesson.reload.timesheet_entry
    end
  end

  test "bỏ điểm danh em cuối cùng thì dòng công biến mất" do
    with_tenant(@ws) do
      AttendanceRecorder.new(lesson: @lesson, student: @students.first).check_in!
      assert @lesson.reload.timesheet_entry.present?
      AttendanceRecorder.new(lesson: @lesson, student: @students.first).undo!
      assert_nil @lesson.reload.timesheet_entry, "không còn ai có mặt thì không còn công"
    end
  end

  test "lớp 1:4 = 2.0 công, và đổi chính sách vẫn không phải sửa code (OQ-05)" do
    with_tenant(@ws) do
      assert_equal 2.0, @ws.credits_for(4)
      @ws.update_business_settings!("credit_table" => { "1" => 0.5, "2" => 1.0, "3" => 1.5, "4" => 1.5 })
      assert_equal 1.5, @ws.reload.credits_for(4)
    end
  end

  test "giáo viên thuê hồ không có chấm công (FR-225)" do
    with_tenant(@ws) do
      renter_user = create(:user)
      Membership.create!(user: renter_user, workspace: @ws, role: "teacher")
      renter = Teacher.create!(workspace: @ws, user: renter_user, kind: "renter", status: "active")
      rental = SwimClass.create!(workspace: @ws, pool: @pool, teacher: renter, class_type: 4,
                                 start_hour: 6, weekdays: [1], start_date: Date.current, kind: "rental")
      LessonGenerator.new(rental).call(total: 2)
      assert_nil PayrollCalculator.new(rental.lessons.first).call
    end
  end

  test "nhận xét không chặn lương theo mặc định (OQ-22)" do
    with_tenant(@ws) do
      refute @ws.feedback_blocks_payroll?
      assert PayrollCalculator.new(@lesson).payable?

      @ws.update_business_settings!("feedback_blocks_payroll" => true)
      refute PayrollCalculator.new(@lesson.reload).payable?, "bật cấu hình thì thiếu nhận xét là chưa tính công"
    end
  end

  test "chốt kỳ khoá dòng công lại, tính lại không đổi số đã chốt" do
    with_tenant(@ws) do
      @students.each { |st| AttendanceRecorder.new(lesson: @lesson, student: st).check_in! }
      PayrollCalculator.new(@lesson.reload).call
      period = PayrollPeriod.create!(workspace: @ws, pool: @pool,
                                     starts_on: @lesson.date, ends_on: @lesson.date)
      period.lock!(by: @c.users[:bod])

      entry = @lesson.reload.timesheet_entry
      assert entry.locked?
      assert_equal 1.5, period.total_credits.to_f

      # Sửa cấu hình rồi tính lại: dòng đã chốt không được đổi.
      @ws.update_business_settings!("credit_table" => { "3" => 3.0 })
      PayrollCalculator.new(@lesson.reload).call
      assert_equal 1.5, entry.reload.credits.to_f
    end
  end

  test "OQ-25: cả 12 buổi đều là buổi học, không buổi nào bị đánh dấu là buổi thi" do
    with_tenant(@ws) do
      assert_equal 12, @class.lessons.count
      assert_equal 0, @class.lessons.where(exam: true).count,
                   "kỳ thi xếp riêng ngoài khoá nên không buổi nào trong khoá là buổi thi"
      assert @class.lessons.order(:session_index).last.session_index == 12
    end
  end
end
