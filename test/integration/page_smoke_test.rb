require "test_helper"

# Mỗi trang của cả 5 cổng phải trả 200 cho đúng vai trò, và chặn đúng vai trò
# không được vào. Đây là lưới an toàn rẻ nhất: một route hỏng hay một view thiếu
# biến là đỏ ngay, không phải mở trình duyệt.
class PageSmokeTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    host_workspace!(@ws)
  end

  # ---- Cổng điều hành & vận hành ---------------------------------------
  test "BOD vào được cả hai cổng back office" do
    sign_in @c.users[:bod]
    ["/merchant/bod", "/merchant/ops", "/merchant/account",
     "/merchant/billing"].each do |path|
      get path
      assert_response :success, "#{path} trả #{response.status}"
    end
  end

  test "sale vào cổng vận hành nhưng bị chặn khỏi cổng điều hành" do
    sign_in @c.users[:sale]
    get "/merchant/ops"
    assert_response :success

    get "/merchant/bod"
    assert_redirected_to "/merchant/ops"
  end

  test "lễ tân bị chặn khỏi cổng vận hành, vào được quầy điểm danh" do
    sign_in @c.users[:receptionist]
    get "/desk"
    assert_response :success

    get "/merchant/ops"
    assert_redirected_to "/desk"
  end

  test "giáo viên chỉ vào được PWA của mình" do
    sign_in @c.users[:teacher]
    get "/teacher"
    assert_response :success

    get "/merchant/ops"
    assert_redirected_to "/teacher"

    get "/desk"
    assert_redirected_to "/teacher"
  end

  test "khách chưa đăng nhập bị đẩy về trang đăng nhập" do
    ["/merchant/ops", "/merchant/bod", "/desk", "/teacher"].each do |path|
      get path
      assert_redirected_to new_user_session_path, "#{path} không chặn khách vãng lai"
    end
  end

  # ---- Super Admin nền tảng --------------------------------------------
  test "super admin xem được các trang nền tảng" do
    host! "example.com"
    sign_in create(:admin_user), scope: :admin_user
    ["/admin", "/admin/workspaces", "/admin/workspaces/new", "/admin/plans",
     "/admin/billing", "/admin/account"].each do |path|
      get path
      assert_response :success, "#{path} trả #{response.status}"
    end
  end

  # ---- Cổng phụ huynh ---------------------------------------------------
  test "phụ huynh quét QR của hộ là vào thẳng, không cần mật khẩu" do
    host! "example.com"
    login_guardian!(@ws, @c.household)
    assert_redirected_to "/w/#{@ws.slug}"
    follow_redirect!
    assert_response :success
    assert_match @c.household.name, response.body
  end

  test "mã QR đã thu hồi thì không vào được nữa" do
    with_tenant(@ws) { @c.household.revoke_qr! }
    host! "example.com"
    login_guardian!(@ws, @c.household)
    assert_redirected_to "/w/#{@ws.slug}/login"
  end

  test "PWA phụ huynh yêu cầu đăng nhập khi chưa có phiên" do
    host! "example.com"
    get "/w/#{@ws.slug}"
    assert_redirected_to "/w/#{@ws.slug}/login"
    follow_redirect!
    assert_response :success
  end

  # ---- PWA manifest -----------------------------------------------------
  test "ba PWA có ba manifest với scope riêng" do
    host! "example.com"
    { "/manifest.webmanifest" => "/", "/teacher/manifest.webmanifest" => "/teacher",
      "/desk/manifest.webmanifest" => "/desk" }.each do |path, scope|
      get path
      assert_response :success
      assert_equal scope, JSON.parse(response.body)["scope"]
    end
  end
end
