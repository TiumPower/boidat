require "test_helper"

# P6: xếp lịch tự động, duyệt đơn nghỉ → học bù, và chỉ số dashboard.
class AutomationTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    @month = Date.current.next_month.beginning_of_month
    host_workspace!(@ws)
  end

  # ---- Bộ xếp lịch tự động (FR-205) -------------------------------------
  test "chỉ đề xuất khung TRỐNG, không đụng lớp đang chạy" do
    with_tenant(@ws) do
      # Thầy đăng ký dạy T2 lúc 17h và 18h; khung 17h đã có lớp đang chạy.
      [17, 18].each do |hour|
        TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: @pool,
                                    month: @month, weekday: 1, hour: hour, submitted_at: Time.current)
      end
      SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                        start_hour: 17, weekdays: [1], start_date: @month, status: "running")

      run = AutoScheduler.new(pool: @pool, month: @month, workspace: @ws).build_draft
      hours = run.proposal_rows.map { |r| r[:hour] }
      assert_equal [18], hours, "khung đã có lớp đang chạy phải bị khoá cứng"
      assert_equal "draft", run.status, "kết quả luôn dừng ở bản nháp"
      assert_equal 1, run.metrics["locked_classes"]
    end
  end

  test "không có ai gửi lịch đăng ký thì không đề xuất gì" do
    with_tenant(@ws) do
      run = AutoScheduler.new(pool: @pool, month: @month, workspace: @ws).build_draft
      assert_equal 0, run.proposal_rows.size
      assert_equal 0, run.metrics["availability_submitted"]
    end
  end

  test "ưu tiên giáo viên đang ít công hơn" do
    with_tenant(@ws) do
      busy = @c.teacher
      idle_user = create(:user)
      Membership.create!(user: idle_user, workspace: @ws, role: "teacher")
      idle = Teacher.create!(workspace: @ws, user: idle_user, teacher_level: busy.teacher_level, kind: "staff")
      TeacherPool.create!(workspace: @ws, teacher: idle, pool: @pool)

      [busy, idle].each do |t|
        TeacherAvailability.create!(workspace: @ws, teacher: t, pool: @pool, month: @month,
                                    weekday: 2, hour: 18, submitted_at: Time.current)
      end

      # Thầy "busy" đã có 20 công trong tháng.
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: busy, class_type: 2,
                              start_hour: 6, weekdays: [1], start_date: @month, status: "running")
      LessonGenerator.new(cls).call(total: 2)
      lesson = cls.lessons.first
      TimesheetEntry.create!(workspace: @ws, pool: @pool, teacher: busy, lesson: lesson,
                             headcount: 2, credits: 20, rate: 0, amount: 0)

      run = AutoScheduler.new(pool: @pool, month: @month, workspace: @ws).build_draft
      assert_equal idle.id, run.proposal_rows.first[:teacher_id],
                   "slot đầu tiên phải về tay giáo viên đang ít công"
    end
  end

  test "áp dụng chỉ giữ những khung admin còn tích" do
    with_tenant(@ws) do
      [17, 18, 19].each do |hour|
        TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: @pool,
                                    month: @month, weekday: 3, hour: hour, submitted_at: Time.current)
      end
      run = AutoScheduler.new(pool: @pool, month: @month, workspace: @ws).build_draft
      keep = ["#{@c.teacher.id}:3:17"]
      kept = run.apply!(by: @c.users[:bod], keep: keep)

      assert_equal 1, kept
      assert run.reload.applied?
      assert_equal [17], run.proposal_rows.map { |r| r[:hour] }
    end
  end

  # ---- Duyệt đơn nghỉ → học bù (FR-211) ---------------------------------
  test "duyệt đơn nghỉ thì huỷ buổi, KHÔNG trừ buổi, và tạo yêu cầu học bù" do
    with_tenant(@ws) do
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                              start_hour: 17, weekdays: [Date.current.wday], start_date: Date.current,
                              status: "running")
      LessonGenerator.new(cls).call(total: 3)
      enrollment = Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student,
                                      swim_class: cls, sessions_total: 12, status: "active")
      lesson = cls.lessons.first
      AttendanceRecorder.new(lesson: lesson, student: @c.student).check_in!
      assert_equal 1, enrollment.reload.sessions_used

      request = LeaveRequest.create!(workspace: @ws, teacher: @c.teacher, lesson_ids: [lesson.id],
                                     reason: "Việc gia đình", status: "pending")
      LeaveApproval.new(request, actor: @c.users[:admin]).approve!

      assert_equal "cancelled", lesson.reload.status
      assert_equal 0, enrollment.reload.sessions_used, "buổi bị huỷ do thầy nghỉ không được trừ (BR-10)"
      assert_nil lesson.timesheet_entry, "không trả công cho buổi chính thầy xin nghỉ"

      makeup = MakeupRequest.find_by(enrollment: enrollment, from_lesson: lesson)
      assert makeup, "phải tạo yêu cầu học bù cho từng học viên"
      assert_equal "teacher_leave", makeup.origin

      note = Notification.find_by(recipient: @c.guardian, kind: "teacher_leave")
      assert note.requires_ack?, "phụ huynh phải xác nhận phương án (OQ-16)"
    end
  end

  test "gợi ý học bù xếp đúng thứ tự ưu tiên khách chốt" do
    with_tenant(@ws) do
      level = @c.teacher.teacher_level
      origin = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                                 start_hour: 17, weekdays: [1], start_date: Date.current, status: "running")
      LessonGenerator.new(origin).call(total: 3)
      enrollment = Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student,
                                      swim_class: origin, sessions_total: 12, status: "active")

      # Cùng thầy, khung giờ khác → ưu tiên 1.
      other_slot = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                                     start_hour: 18, weekdays: [3], start_date: Date.current, status: "running")
      LessonGenerator.new(other_slot).call(total: 3)

      # Thầy khác cùng level → ưu tiên 2.
      peer_user = create(:user)
      Membership.create!(user: peer_user, workspace: @ws, role: "teacher")
      peer = Teacher.create!(workspace: @ws, user: peer_user, teacher_level: level, kind: "staff")
      TeacherPool.create!(workspace: @ws, teacher: peer, pool: @pool)
      peer_class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: peer, class_type: 2,
                                     start_hour: 19, weekdays: [4], start_date: Date.current, status: "running")
      LessonGenerator.new(peer_class).call(total: 3)

      options = MakeupOptions.new(enrollment: enrollment, from_lesson: origin.lessons.first).call
      assert options.any?
      assert_equal 1, options.first.priority
      assert_equal @c.teacher.id, options.first.teacher.id, "ưu tiên giữ nguyên thầy"
      assert options.map(&:priority).include?(2), "phải có phương án thầy khác cùng level"
    end
  end

  # ---- Chỉ số dashboard (FR-102) ----------------------------------------
  test "tỷ lệ lấp đầy = tiết có học viên ÷ tiết đã phân lịch (OQ-11)" do
    with_tenant(@ws) do
      filled = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                                 start_hour: 17, weekdays: [1, 3], start_date: Date.current.beginning_of_month,
                                 status: "running")
      LessonGenerator.new(filled).call(total: 4)
      Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student, swim_class: filled,
                         sessions_total: 12, status: "active")

      empty = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                                start_hour: 18, weekdays: [1, 3], start_date: Date.current.beginning_of_month,
                                status: "running")
      LessonGenerator.new(empty).call(total: 4)

      metrics = PoolMetrics.new(workspace: @ws, pools: [@pool],
                                period: PeriodFilter.new("month")).call
      # 4 tiết có học viên trên tổng 8 tiết đã phân lịch (lớp trống vẫn nằm ở mẫu số).
      assert_equal 50, metrics[:fill_rate]
      assert_match "/", metrics[:fill_detail]
    end
  end

  test "doanh thu tách hai dòng khoá học và cho thuê (OQ-26)" do
    with_tenant(@ws) do
      Order.create!(workspace: @ws, pool: @pool, amount: 4_800_000, kind: "course").apply_payment!
      Order.create!(workspace: @ws, pool: @pool, amount: 12_000_000, kind: "rental").apply_payment!

      metrics = PoolMetrics.new(workspace: @ws, pools: [@pool], period: PeriodFilter.new("month")).call
      assert_equal 4_800_000, metrics[:revenue_course]
      assert_equal 12_000_000, metrics[:revenue_rental]
    end
  end

  test "chỉ số vắng không báo phản ánh hệ quả của BR-12" do
    with_tenant(@ws) do
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                              start_hour: 17, weekdays: [Date.current.wday],
                              start_date: Date.current, status: "running")
      LessonGenerator.new(cls).call(total: 2)
      second = create(:student, workspace: @ws, household: @c.household, pool: @pool, name: "Bé hai")
      [@c.student, second].each do |st|
        Enrollment.create!(workspace: @ws, pool: @pool, student: st, swim_class: cls,
                           sessions_total: 12, status: "active")
      end
      lesson = cls.lessons.find_by(date: Date.current)
      AttendanceRecorder.new(lesson: lesson, student: @c.student).check_in!

      metrics = PoolMetrics.new(workspace: @ws, pools: [@pool], period: PeriodFilter.new("month")).call
      assert_equal 50.0, metrics[:no_show_rate], "1/2 học viên không đến"
    end
  end

  test "BOD xem được dashboard và xuất được CSV" do
    sign_in @c.users[:bod]
    get "/merchant/bod"
    assert_response :success

    get "/merchant/bod/reports.csv"
    assert_response :success
    assert_equal "﻿", response.body[0], "CSV phải có BOM để Excel đọc đúng tiếng Việt"
    assert_match "Doanh thu khoá học", response.body
  end
end
