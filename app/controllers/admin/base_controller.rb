module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_admin_user!
    before_action :no_browser_cache

    helper_method :nav_key

    private

    # Super Admin nền tảng làm việc xuyên workspace — không bao giờ scope tenant.
    def nav_key = nil
  end
end
