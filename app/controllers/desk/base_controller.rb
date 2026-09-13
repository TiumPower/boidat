module Desk
  # Quầy điểm danh (S3) — PWA mobile cho lễ tân tại hồ.
  class BaseController < ApplicationController
    include StaffScoped
    layout "desk"

    before_action :require_front_desk!

    private

    def require_front_desk!
      return if current_membership&.front_desk?
      redirect_to home_path_for_role(current_membership&.role),
                  alert: "Cổng điểm danh chỉ dành cho lễ tân và quản lý hồ."
    end
  end
end
