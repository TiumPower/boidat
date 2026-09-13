require "test_helper"

# Ở production mỗi trung tâm có subdomain riêng, nên sau đăng nhập là một cú nhảy
# khác host — Rails 7 chặn mặc định. Lỗi này KHÔNG xuất hiện ở dev (dev chạy một
# host duy nhất), nên phải khoá bằng test.
class CrossSubdomainRedirectTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
  end

  test "chỉ cho phép nhảy sang host thuộc nền tảng của mình" do
    controller = ApplicationController.new
    host = ApplicationController::PLATFORM_HOST

    assert controller.send(:own_platform_url?, "https://#{@ws.subdomain}.#{host}/merchant/bod")
    assert controller.send(:own_platform_url?, "https://#{host}/merchant")
    refute controller.send(:own_platform_url?, "https://ke-tan-cong.example.com/merchant")
    refute controller.send(:own_platform_url?, "/merchant/bod"), "đường dẫn tương đối thì không cần mở"
    refute controller.send(:own_platform_url?, "https://#{host}.evil.com/")
  end
end
