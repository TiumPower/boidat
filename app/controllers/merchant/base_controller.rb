module Merchant
  class BaseController < ApplicationController
    include StaffScoped
    layout "merchant"

    private

    # Cổng vận hành (S2) mở cho BOD / admin / sale.
    def require_operations!
      return if current_membership&.operations?
      redirect_to fallback_home_path, alert: "Bạn không có quyền vào cổng vận hành."
    end

    # Cổng điều hành (S1) chỉ mở cho BOD.
    def require_executive!
      return if current_membership&.executive?
      redirect_to fallback_home_path, alert: "Chỉ Ban giám đốc mới vào được cổng điều hành."
    end

    def fallback_home_path
      home_path_for_role(current_membership&.role)
    end
  end
end
