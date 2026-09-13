module Merchant
  # Điều hướng người dùng về đúng cổng của vai trò họ, và xử lý nút chuyển hồ.
  class HomeController < BaseController
    def show
      redirect_to fallback_home_path
    end

    def switch_pool
      if switch_pool!(params[:pool_id])
        redirect_back fallback_location: fallback_home_path,
                      notice: "Đang xem #{current_pool.name}."
      else
        redirect_back fallback_location: fallback_home_path,
                      alert: "Bạn không được gán vào hồ này."
      end
    end
  end
end
