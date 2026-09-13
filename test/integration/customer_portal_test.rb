require "test_helper"

# Cổng phụ huynh (S5): đăng nhập QR, tiến độ, nhận xét, hoá đơn, chat, hồ sơ.
class CustomerPortalTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      @course.ensure_session_plan!
      @class = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, course: @course,
                                 class_type: 2, start_hour: 17, weekdays: [1],
                                 start_date: 2.weeks.ago.to_date.beginning_of_week, status: "running")
      LessonGenerator.new(@class).call(total: 4)
      @enrollment = Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student,
                                       swim_class: @class, sessions_total: 12, sessions_used: 3,
                                       status: "active")
      @order = Order.create!(workspace: @ws, pool: @pool, household: @c.household, student: @c.student,
                             enrollment: @enrollment, amount: 4_800_000, status: "unpaid")
    end
    host! "example.com"
    login_guardian!(@ws, @c.household)
  end

  test "màn hình gia đình liệt kê học viên và cảnh báo thiếu ảnh khuôn mặt" do
    get "/w/#{@ws.slug}"
    assert_response :success
    assert_match @c.student.name, response.body
    assert_match "Cần chụp ảnh khuôn mặt", response.body
  end

  test "trang học viên hiện tiến độ và nhận xét của giáo viên" do
    with_tenant(@ws) do
      lesson = @class.lessons.first
      SessionFeedback.create!(workspace: @ws, pool: @pool, lesson: lesson, student: @c.student,
                              teacher: @c.teacher, tag: "progress",
                              body: "Ngọc đã thở nghiêng được 15m liên tục.")
    end
    get "/w/#{@ws.slug}/students/#{@c.student.id}"
    assert_response :success
    assert_match "3/12 buổi", response.body
    assert_match "thở nghiêng", response.body
    assert_match "Tiến bộ tốt", response.body
  end

  test "không xem được học viên của hộ khác" do
    other = with_tenant(@ws) do
      hh = create(:household, workspace: @ws)
      create(:student, workspace: @ws, household: hh, pool: @pool, name: "Bé nhà khác")
    end
    get "/w/#{@ws.slug}/students/#{other.id}"
    assert_response :not_found
  end

  test "chủ hộ xem được hoá đơn" do
    get "/w/#{@ws.slug}/invoices"
    assert_response :success
    assert_match @order.code, response.body
  end

  test "người đưa đón bị chặn khỏi mục thanh toán (OQ-03)" do
    pickup = with_tenant(@ws) { create(:guardian, workspace: @ws, household: @c.household, role: "pickup") }
    # Đăng nhập bằng chính người đưa đón.
    with_tenant(@ws) { @c.household.guardians.where.not(id: pickup.id).destroy_all }
    login_guardian!(@ws, @c.household.reload)

    get "/w/#{@ws.slug}/invoices"
    assert_redirected_to "/w/#{@ws.slug}"
    assert_match "Chỉ chủ gia đình", flash[:alert]
  end

  test "đăng ký ảnh khuôn mặt bắt buộc tích ô đồng ý (FR-402)" do
    file = fixture_file_upload_stub
    post "/w/#{@ws.slug}/faces/#{@c.student.id}", params: { photo: file }
    assert_match "đồng ý", flash[:alert]
    with_tenant(@ws) { assert_nil @c.student.reload.face_profile }
  end

  test "tích đồng ý thì lưu ảnh và ghi lại bằng chứng đồng ý" do
    post "/w/#{@ws.slug}/faces/#{@c.student.id}",
         params: { photo: fixture_file_upload_stub, consent: "1" }
    with_tenant(@ws) do
      profile = @c.student.reload.face_profile
      assert profile, "phải tạo hồ sơ khuôn mặt"
      assert profile.photos.attached?
      consent = BiometricConsent.find_by(student: @c.student)
      assert consent, "phải lưu bằng chứng đồng ý"
      assert_equal BiometricConsent::CURRENT_TERMS_VERSION, consent.terms_version
    end
  end

  test "phụ huynh yêu cầu xoá dữ liệu sinh trắc học thì xoá và thu hồi đồng ý" do
    post "/w/#{@ws.slug}/faces/#{@c.student.id}",
         params: { photo: fixture_file_upload_stub, consent: "1" }
    delete "/w/#{@ws.slug}/faces/#{@c.student.id}"
    with_tenant(@ws) do
      profile = @c.student.reload.face_profile
      assert profile.deleted_at.present?
      refute @c.student.face_registered?
      assert_equal 0, BiometricConsent.active.where(student: @c.student).count
    end
  end

  test "nhắn tin cho admin tạo hội thoại của hồ" do
    post "/w/#{@ws.slug}/chat/messages", params: { body: "Cho bé nghỉ thứ 7 nhé" }
    with_tenant(@ws) do
      conv = Conversation.find_by(household: @c.household, pool: @pool)
      assert conv
      assert_equal 1, conv.messages.count
      assert_equal 1, conv.staff_unread, "admin phải thấy tin chưa đọc"
    end
  end

  test "xác nhận thông báo thầy nghỉ được ghi lại (OQ-16)" do
    note = with_tenant(@ws) do
      Notification.create!(workspace: @ws, recipient: @c.guardian, kind: "teacher_leave",
                           title: "Thầy nghỉ buổi 23/09", body: "Chọn phương án", requires_ack: true)
    end
    post "/w/#{@ws.slug}/notifications/#{note.id}/ack", params: { choice: "follow_teacher" }
    with_tenant(@ws) do
      note.reload
      assert note.acknowledged?
      assert_equal "follow_teacher", note.ack_choice
    end
  end

  private

  # Ảnh PNG 1×1 tối thiểu — đủ để test luồng upload mà không cần file thật.
  def fixture_file_upload_stub
    png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
    Rack::Test::UploadedFile.new(StringIO.new(png), "image/png", original_filename: "face.png")
  end
end
