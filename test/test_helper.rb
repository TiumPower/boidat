ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    include FactoryBot::Syntax::Methods
    include TenancyHelper

    # Run a block with a tenant set (acts_as_tenant).
    def with_tenant(ws, &blk) = ActsAsTenant.with_tenant(ws, &blk)
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Back office và PWA nhân sự đều nhận diện trung tâm qua subdomain.
  def host_workspace!(ws) = host! "#{ws.subdomain}.example.com"

  # Đăng nhập phụ huynh: cổng này dùng cookie ký chứ không phải Devise, nên test
  # đi qua đúng luồng thật (quét QR của hộ) thay vì set cookie bằng tay.
  def login_guardian!(ws, household)
    get "/w/#{ws.slug}/q/#{household.qr_token}"
  end
end
