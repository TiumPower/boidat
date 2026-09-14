require "test_helper"

# Trang công khai ở host trần (boidat.czin.net, chưa xác định được trung tâm).
# Đây là trang duy nhất dùng layout `marketing` và các khoá `landing.*`, là
# trang duy nhất có nút đổi VI/EN — và trước đây là trang duy nhất KHÔNG có
# test nào chạm tới. Nó cũng là trang người lạ nhìn thấy đầu tiên.
#
# `config.i18n.raise_on_missing_translations` đang bật ở môi trường test, nên
# mỗi lần `get` ở đây là một lần khẳng định không thiếu bản dịch nào — đúng cái
# lưới cần có sau khi dọn hai file locale từ 2.462 dòng xuống còn 194.
class LandingPageTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    host! "example.com"   # host trần, không phải subdomain của trung tâm nào
  end

  test "host trần hiện trang giới thiệu, không đòi đăng nhập" do
    get "/"
    assert_response :success
    assert_match "BƠI ĐẠT", response.body
  end

  test "trang giới thiệu liệt kê các trung tâm đang hoạt động" do
    get "/"
    assert_match @c.workspace.name, response.body
  end

  test "hiển thị được ở cả tiếng Việt lẫn tiếng Anh" do
    I18n.available_locales.each do |locale|
      get "/set_locale/#{locale}"
      get "/"
      assert_response :success, "trang giới thiệu vỡ ở locale #{locale}"
      refute_match "translation missing", response.body
    end
  ensure
    I18n.locale = I18n.default_locale
  end

  test "locale lạ bị bỏ qua chứ không làm vỡ trang" do
    get "/set_locale/xx"
    get "/"
    assert_response :success
  end
end
