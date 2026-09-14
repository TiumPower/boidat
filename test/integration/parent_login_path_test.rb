require "test_helper"

# Cổng phụ huynh và cổng nhân sự chạy trên CÙNG một host ở production
# (boidat.boidat.czin.net), nên đường dẫn đăng nhập của hai bên không được
# đụng nhau.
#
# Trước đây chúng đụng nhau. Segment `(/w/:workspace_slug)` là tuỳ chọn, nên ở
# chế độ subdomain — chế độ chạy thật — đường "login" của phụ huynh rút gọn
# thành đúng `/login`, trùng route Devise của nhân sự khai phía trên và thua
# nó. Phụ huynh mở app mà chưa có phiên rơi thẳng vào form email + mật khẩu
# của nhân sự: thứ họ không có, không kèm lối quét QR lẫn lối SĐT + OTP, và
# không có cách nào đi tiếp.
class ParentLoginPathTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
  end

  test "trên subdomain, phụ huynh chưa đăng nhập thấy form của phụ huynh" do
    host_workspace!(@ws)
    get "/"
    assert_response :redirect
    follow_redirect!
    assert_response :success

    assert_match "QR", response.body, "phải có lối quét mã QR của hộ"
    refute_match "Mật khẩu", response.body, "không được đẩy phụ huynh vào form đăng nhập của nhân sự"
  end

  test "đường đăng nhập của phụ huynh không rút gọn thành /login" do
    host_workspace!(@ws)
    refute_equal "/login", member_login_path,
                 "trùng route Devise của nhân sự thì phụ huynh sẽ thấy nhầm form"
  end

  test "/login vẫn là của nhân sự, trên mọi host" do
    host_workspace!(@ws)
    get "/login"
    assert_response :success
    assert_match "Mật khẩu", response.body
  end

  test "chế độ /w/:slug vẫn vào được cổng phụ huynh" do
    host! "example.com"
    get "/w/#{@ws.slug}/vao"
    assert_response :success
    assert_match "QR", response.body
  end

  test "đăng xuất rồi thì quay về form của phụ huynh, không phải của nhân sự" do
    host_workspace!(@ws)
    login_guardian!(@ws, @c.household)
    delete member_logout_path
    assert_response :redirect
    follow_redirect!
    assert_match "QR", response.body
  end
end
