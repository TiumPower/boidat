require "test_helper"

# OQ-03: chủ hộ xem được lịch sử thanh toán, người đưa đón thì không.
#
# Quy tắc này đã có sẵn trong `Guardian#can_view_payments?` và
# `require_payment_access!` từ đầu, nhưng suốt một thời gian nó KHÔNG hề chạy:
# mã QR là của cả hộ, và mọi lần quét đều đăng nhập thành chủ hộ. Người đưa đón
# cầm đúng mã ấy là đọc được toàn bộ hoá đơn — quy tắc chỉ còn là cái nhãn trên
# màn hình. Bộ test này khoá lại đúng chỗ đó: mã QR phải là của TỪNG NGƯỜI.
class GuardianQrScopeTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    with_tenant(@ws) do
      @owner = @c.household.guardians.find_by(role: "owner") ||
               create(:guardian, workspace: @ws, household: @c.household, role: "owner")
      @pickup = create(:guardian, workspace: @ws, household: @c.household,
                       role: "pickup", name: "Bà ngoại đón cháu")
      @order = Order.create!(workspace: @ws, pool: @pool, household: @c.household,
                             student: @c.student, amount: 4_800_000, status: "unpaid")
    end
    host! "example.com"
  end

  test "mỗi người giám hộ có mã QR riêng, không dùng chung mã của hộ" do
    assert @owner.qr_token.present?
    assert @pickup.qr_token.present?
    refute_equal @owner.qr_token, @pickup.qr_token,
                 "Dùng chung mã thì không thể biết ai đang quét, và OQ-03 mất hiệu lực"
  end

  test "quét mã của người đưa đón thì vào đúng danh tính người đưa đón" do
    get "/w/#{@ws.slug}/q/#{@pickup.qr_token}"
    follow_redirect!
    assert_response :success
    assert_match @pickup.name, response.body
  end

  test "người đưa đón KHÔNG xem được hoá đơn dù quét mã hợp lệ" do
    get "/w/#{@ws.slug}/q/#{@pickup.qr_token}"
    get "/w/#{@ws.slug}/invoices"
    assert_response :redirect
    refute_match @order.amount.to_i.to_s, response.body.to_s
  end

  test "người đưa đón KHÔNG tự đăng ký khoá mới được — tái ký là phát sinh tiền" do
    get "/w/#{@ws.slug}/q/#{@pickup.qr_token}"
    get "/w/#{@ws.slug}/students/#{@c.student.id}/enroll"
    assert_response :redirect
  end

  test "chủ hộ quét mã của mình thì vẫn xem được hoá đơn" do
    get "/w/#{@ws.slug}/q/#{@owner.qr_token}"
    get "/w/#{@ws.slug}/invoices"
    assert_response :success
    assert_match "4.800.000", response.body
  end

  test "mã cũ ở cấp hộ vẫn dùng được và dẫn về chủ hộ, để link đã phát ra không chết" do
    get "/w/#{@ws.slug}/q/#{@c.household.qr_token}"
    follow_redirect!
    assert_response :success
    assert_match @owner.name, response.body
  end

  test "thu hồi mã của một người không làm chết mã của người còn lại" do
    with_tenant(@ws) { @pickup.revoke_qr! }

    get "/w/#{@ws.slug}/q/#{@pickup.qr_token}"
    assert_redirected_to member_login_path(workspace_slug: @ws.slug)

    get "/w/#{@ws.slug}/q/#{@owner.qr_token}"
    follow_redirect!
    assert_response :success
    assert_match @owner.name, response.body
  end
end
