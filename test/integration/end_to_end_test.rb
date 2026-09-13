require "test_helper"

# E2E: đi trọn vòng đời một học viên qua cả 5 cổng, đúng thứ tự thực tế xảy ra ở
# trung tâm. Mỗi bước dùng đúng HTTP request mà người thật sẽ gửi — không gọi
# tắt vào model — để bắt được lỗi ở tầng route, quyền, và view.
#
#   sale chốt slot → hộ + QR → cam kết ký → đơn hàng → phụ huynh vào PWA →
#   chụp ảnh khuôn mặt → thanh toán PayOS → lễ tân điểm danh → trừ buổi →
#   giáo viên nhận xét → công lên bảng → admin chốt kỳ → BOD thấy doanh thu →
#   phụ huynh tự tái ký
class EndToEndTest < ActionDispatch::IntegrationTest
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
      @c.teacher.teacher_level.update!(max_students_per_slot: 3, pay_rate_per_credit: 90_000)
      # Giáo viên đã gửi lịch dạy — điều kiện để có slot trống.
      [17, 18].each do |hour|
        [Date.current.beginning_of_month, Date.current.next_month.beginning_of_month].each do |m|
          TeacherAvailability.create!(workspace: @ws, teacher: @c.teacher, pool: @pool, month: m,
                                      weekday: Date.current.wday, hour: hour, submitted_at: Time.current)
        end
      end
    end
  end

  test "vòng đời trọn vẹn: từ lúc sale chốt khách tới lúc phụ huynh tái ký" do
    # ---- 1. SALE: mở bảng lịch, thấy slot trống, đăng ký học viên mới --------
    host_workspace!(@ws)
    sign_in @c.users[:sale]

    get "/merchant/ops", params: { view: "day", date: Date.current.to_s }
    assert_response :success
    assert_match "Slot trống", response.body

    post "/merchant/ops/registrations", params: { registration: {
      student_name: "Trần Bảo Ngọc", birthdate: 8.years.ago.to_date.to_s, gender: "nữ",
      health_notes: "Hen suyễn nhẹ", source: "Giới thiệu",
      guardian_name: "Trần Văn Đạt", guardian_phone: "0908221447", guardian_relation: "Bố",
      teacher_id: @c.teacher.id, start_hour: 17, weekday_list: Date.current.wday.to_s,
      start_date: Date.current.to_s, package_id: @package.id, customer_type: "new"
    } }
    assert_response :redirect

    student, enrollment, order, household = with_tenant(@ws) do
      s = Student.find_by!(name: "Trần Bảo Ngọc")
      [s, s.enrollments.first, Order.order(:created_at).last, s.household]
    end
    assert_equal 12, with_tenant(@ws) { enrollment.swim_class.lessons.count }
    assert_equal 4_800_000, order.amount
    assert_equal "unpaid", order.status

    # Cả giáo viên lẫn phụ huynh phải được báo ngay (FR-222).
    with_tenant(@ws) do
      assert Notification.where(recipient: @c.teacher.user, kind: "class_created").exists?
      assert Notification.where(recipient: household.owner, kind: "class_created").exists?
    end

    # ---- 2. SALE: ký cam kết điện tử ----------------------------------------
    get "/merchant/ops/contracts/new", params: { enrollment_id: enrollment.id }
    assert_response :success

    post "/merchant/ops/contracts", params: { enrollment_id: enrollment.id,
                                              guardian_name: "Trần Văn Đạt" }
    contract = with_tenant(@ws) { Contract.order(:created_at).last }
    assert contract.signed?
    assert contract.pdf.attached?
    assert_equal 64, contract.sha256.length

    get "/merchant/ops/contracts/#{contract.id}/download"
    assert_response :success
    assert_equal "%PDF", response.body[0, 4]

    # ---- 3. PHỤ HUYNH: quét QR vào PWA, chụp ảnh khuôn mặt ------------------
    reset!
    host! "#{@ws.subdomain}.example.com"
    get "/q/#{household.qr_token}"
    follow_redirect!
    assert_response :success
    assert_match "Trần Bảo Ngọc", response.body
    assert_match "Cần chụp ảnh khuôn mặt", response.body

    post "/faces/#{student.id}", params: { photo: png_upload, consent: "1" }
    with_tenant(@ws) do
      assert student.reload.face_registered?
      assert BiometricConsent.where(student: student).active.exists?
    end

    # ---- 4. PHỤ HUYNH: thanh toán → webhook PayOS ---------------------------
    get "/invoices"
    assert_response :success
    assert_match order.code, response.body

    with_tenant(@ws) { order.reassign_payos_code! }
    payos_webhook(order.reload)
    assert_equal "paid", with_tenant(@ws) { order.reload.status }
    assert_equal 1, with_tenant(@ws) { order.payments.count }

    # Webhook về lần hai không được ghi nhận thêm lần nữa.
    payos_webhook(order)
    assert_equal 1, with_tenant(@ws) { order.reload.payments.count }

    # Cả phụ huynh lẫn admin đều được báo đã thu tiền.
    with_tenant(@ws) do
      assert Notification.where(recipient: household.owner, kind: "invoice").exists?
      assert Notification.where(recipient_type: "User", kind: "invoice").exists?
    end

    # ---- 5. LỄ TÂN: quét ở quầy, trừ đúng một buổi --------------------------
    reset!
    host_workspace!(@ws)
    sign_in @c.users[:receptionist]

    lesson = with_tenant(@ws) { enrollment.swim_class.lessons.order(:session_index).first }
    with_tenant(@ws) { lesson.update!(date: Date.current) }

    get "/desk/scan", params: { student_id: student.id }
    assert_response :success
    assert_match "Buổi 1 / 12", response.body

    post "/desk/scan", params: { student_id: student.id }
    assert_redirected_to desk_root_path
    with_tenant(@ws) do
      assert_equal 1, enrollment.reload.sessions_used
      assert lesson.reload.attendances.first.deducted
      assert_equal "done", lesson.status
    end

    # Học viên hồ khác quét ở đây phải bị chặn (FR-235).
    foreign = with_tenant(@ws) do
      hh = create(:household, workspace: @ws, name: "Hộ Thủ Đức")
      create(:guardian, workspace: @ws, household: hh)
      create(:student, workspace: @ws, household: hh, pool: @c.pools.last, name: "Lê Minh Khang")
    end
    post "/desk/scan", params: { student_id: foreign.id }
    assert_match "thuộc cơ sở", flash[:alert]

    # ---- 6. GIÁO VIÊN: nhận xét, công tự lên bảng ---------------------------
    reset!
    host_workspace!(@ws)
    sign_in @c.users[:teacher]

    get "/teacher"
    assert_response :success
    assert_match "Trần Bảo Ngọc".split.last, response.body

    post "/teacher/lessons/#{lesson.id}/feedbacks", params: {
      feedbacks: { student.id.to_s => { tag: "progress", body: "Ngọc đã thở nghiêng được 15m." } }
    }
    with_tenant(@ws) do
      assert SessionFeedback.where(lesson: lesson, student: student).exists?
      entry = lesson.reload.timesheet_entry
      assert entry, "điểm danh xong là phải có dòng công"
      assert_equal 0.5, entry.credits.to_f, "một em có mặt = 0.5 công (OQ-06)"
    end

    get "/teacher/timesheet", params: { range: "month" }
    assert_response :success

    # ---- 7. PHỤ HUYNH: xem được nhận xét ------------------------------------
    reset!
    host! "#{@ws.subdomain}.example.com"
    get "/q/#{household.qr_token}"
    get "/students/#{student.id}"
    assert_response :success
    assert_match "thở nghiêng", response.body
    assert_match "Tiến bộ tốt", response.body

    # ---- 8. ADMIN: chốt kỳ công --------------------------------------------
    reset!
    host_workspace!(@ws)
    sign_in @c.users[:admin]

    post "/merchant/ops/timesheets/lock",
         params: { from: Date.current.beginning_of_month.to_s, to: Date.current.to_s }
    assert_response :redirect
    with_tenant(@ws) do
      assert lesson.reload.timesheet_entry.locked?
      assert PayrollPeriod.where.not(locked_at: nil).exists?
      assert Notification.where(recipient: @c.teacher.user, kind: "payroll").exists?
    end

    # ---- 9. BOD: doanh thu và tỷ lệ lấp đầy phản ánh đúng -------------------
    reset!
    host_workspace!(@ws)
    sign_in @c.users[:bod]

    get "/merchant/bod", params: { period: "month" }
    assert_response :success
    metrics = with_tenant(@ws) do
      PoolMetrics.new(workspace: @ws, pools: [@pool], period: PeriodFilter.new("month")).call
    end
    assert_equal 4_800_000, metrics[:revenue_course]
    assert_equal 1, metrics[:lessons_taught]
    assert metrics[:fill_rate].positive?

    get "/merchant/bod/reports.csv"
    assert_response :success
    assert_match "Doanh thu khoá học", response.body

    # ---- 10. PHỤ HUYNH: tự tái ký khoá mới ----------------------------------
    reset!
    host! "#{@ws.subdomain}.example.com"
    get "/q/#{household.qr_token}"

    get "/students/#{student.id}/enroll"
    assert_response :success

    assert_difference -> { with_tenant(@ws) { Order.count } }, 1 do
      post "/students/#{student.id}/enroll",
           params: { package_id: @package.id, slot: "#{@c.teacher.id}:#{Date.current.wday}:18" }
    end
    with_tenant(@ws) do
      renewal = Order.order(:created_at).last
      assert_equal "renewal", renewal.kind
      assert_equal student.id, renewal.student_id
      assert_equal 2, student.reload.enrollments.count, "học viên cũ, không tạo hồ sơ mới"
      assert_equal 1, Student.where(name: "Trần Bảo Ngọc").count
    end
  end

  test "vòng đời đơn nghỉ: giáo viên xin nghỉ, admin duyệt, phụ huynh chọn buổi bù" do
    with_tenant(@ws) do
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                                 class_type: 2, start_hour: 17, weekdays: [Date.current.wday],
                                 start_date: Date.current, status: "running")
      LessonGenerator.new(@class).call(total: 6)
      @enrollment = Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student,
                                       swim_class: @class, sessions_total: 12, status: "active")
      # Một lớp khác cùng thầy để có phương án học bù.
      alt = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                              class_type: 2, start_hour: 18, weekdays: [Date.current.wday],
                              start_date: Date.current, status: "running")
      LessonGenerator.new(alt).call(total: 6)
    end
    target = with_tenant(@ws) { @class.lessons.where("date > ?", Date.current).order(:date).first }

    # Giáo viên gửi đơn
    host_workspace!(@ws)
    sign_in @c.users[:teacher]
    post "/teacher/leaves", params: { lesson_ids: [target.id], reason: "Việc gia đình" }
    request_id = with_tenant(@ws) { LeaveRequest.order(:created_at).last.id }

    # Admin duyệt
    reset!
    host_workspace!(@ws)
    sign_in @c.users[:admin]
    get "/merchant/ops/leave-requests"
    assert_response :success
    patch "/merchant/ops/leave-requests/#{request_id}/approve", params: { note: "Đã sắp lịch bù" }

    with_tenant(@ws) do
      assert_equal "cancelled", target.reload.status
      assert_equal 0, @enrollment.reload.sessions_used, "buổi bị huỷ không trừ của học viên"
      assert MakeupRequest.pending.where(student: @c.student).exists?
    end

    # Phụ huynh nhận thông báo cần xác nhận và chọn buổi bù
    reset!
    host! "#{@ws.subdomain}.example.com"
    get "/q/#{@c.household.qr_token}"
    get "/notifications"
    assert_response :success
    assert_match "Chọn một phương án", response.body

    makeup = with_tenant(@ws) { MakeupRequest.pending.first }
    get "/makeups/#{makeup.id}"
    assert_response :success
    assert_match "Nghỉ theo thầy", response.body

    alt_lesson = with_tenant(@ws) do
      Lesson.where(pool_id: @pool.id, status: "scheduled").where("date >= ?", Date.current)
            .where.not(swim_class_id: @class.id).order(:date).first
    end
    post "/makeups/#{makeup.id}/book", params: { lesson_id: alt_lesson.id }
    with_tenant(@ws) do
      assert_equal "booked", makeup.reload.status
      assert_equal alt_lesson.id, makeup.to_lesson_id
    end
  end

  private

  def png_upload
    png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
    Rack::Test::UploadedFile.new(StringIO.new(png), "image/png", original_filename: "face.png")
  end

  # Giả lập webhook server-to-server của PayOS, ký đúng cách PayosService kiểm tra.
  def payos_webhook(order)
    ENV["PAYOS_CHECKSUM_KEY"] ||= "test-checksum"
    data = { "orderCode" => order.payos_order_code, "amount" => order.total,
             "description" => order.code, "reference" => "FT#{order.id}" }
    signature = OpenSSL::HMAC.hexdigest(
      "SHA256", ENV["PAYOS_CHECKSUM_KEY"],
      data.sort.map { |k, v| "#{k}=#{v}" }.join("&")
    )
    # PayOS đặt chữ ký ở CẤP NGOÀI cùng, không nằm trong data.
    post "/webhooks/payos",
         params: { code: "00", desc: "success", data: data, signature: signature }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
  end
end
