require "test_helper"

# Ở production, cổng phụ huynh chạy trên SUBDOMAIN của trung tâm chứ không phải
# đường dẫn /w/:slug. Hai chế độ sinh URL khác nhau: ở chế độ subdomain, đoạn
# tuỳ chọn `(/w/:workspace_slug)` sẽ nuốt mất tham số vị trí đầu tiên nếu view
# gọi `member_x_path(record)` thay vì `member_x_path(id: record.id)`.
#
# Test dev-mode không bắt được lỗi này vì `default_url_options` đã điền sẵn
# workspace_slug. Đây chính là lỗi đã làm trang Thông báo trả 500 trên production.
class CustomerSubdomainTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      cls = SwimClass.create!(workspace: @ws, pool: @pool, teacher: @c.teacher, class_type: 2,
                              start_hour: 17, weekdays: [1], start_date: 1.week.ago.to_date,
                              status: "running")
      LessonGenerator.new(cls).call(total: 4)
      @enrollment = Enrollment.create!(workspace: @ws, pool: @pool, student: @c.student,
                                       swim_class: cls, sessions_total: 12, status: "active")
      Order.create!(workspace: @ws, pool: @pool, household: @c.household, student: @c.student,
                    enrollment: @enrollment, amount: 4_800_000, status: "unpaid")
      Notification.create!(workspace: @ws, recipient: @c.guardian, kind: "teacher_leave",
                           title: "Thầy nghỉ", body: "Chọn phương án", requires_ack: true)
      MakeupRequest.create!(workspace: @ws, pool: @pool, enrollment: @enrollment,
                            student: @c.student, from_lesson: cls.lessons.first,
                            origin: "teacher_leave", status: "pending")
    end
    # Đúng cách production chạy: subdomain của trung tâm, KHÔNG có /w/:slug.
    host! "#{@ws.subdomain}.example.com"
    get "/q/#{@c.household.qr_token}"
    follow_redirect!
  end

  test "mọi trang của cổng phụ huynh render được ở chế độ subdomain" do
    makeup_id = with_tenant(@ws) { MakeupRequest.first.id }
    order_id  = with_tenant(@ws) { Order.first.id }

    ["/", "/students/#{@c.student.id}", "/invoices", "/invoices/#{order_id}",
     "/makeups", "/makeups/#{makeup_id}", "/notifications", "/chat", "/faces", "/me"].each do |path|
      get path
      assert_response :success, "#{path} trả #{response.status} ở chế độ subdomain"
    end
  end

  test "URL sinh ra không nhét id vào chỗ workspace_slug" do
    get "/notifications"
    assert_response :success
    note_id = with_tenant(@ws) { Notification.first.id }
    assert_match "/notifications/#{note_id}/ack", response.body,
                 "nút xác nhận phải trỏ đúng id, không phải /w/<id>"
    refute_match "/w/#{note_id}", response.body
  end

  test "mã QR của hộ sinh đúng đường dẫn ở chế độ subdomain" do
    # Ảnh QR là SVG nên URL không nằm dạng text trong trang — kiểm tra thẳng
    # helper, đúng chỗ lỗi từng xảy ra.
    token = @c.household.qr_token
    assert_equal "/q/#{token}", member_qr_login_path(qr_token: token)
    assert_equal "/w/#{@ws.slug}/q/#{token}",
                 member_qr_login_path(qr_token: token, workspace_slug: @ws.slug),
                 "chế độ đường dẫn (dev) vẫn phải giữ tiền tố /w/:slug"

    get "/me"
    assert_response :success
  end
end
