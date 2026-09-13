# QUAN TRỌNG: namespace controller phải là `Coach`, KHÔNG phải `Teacher` —
# model `Teacher` và module `Teacher::` va nhau dưới Zeitwerk (đúng lỗi mà dự án
# Loyalty đã gặp với `Member`). Route helper vẫn là `teacher_*`, path vẫn `/teacher`.
module Coach
  # Cổng giáo viên (S4) — PWA mobile.
  class BaseController < ApplicationController
    include StaffScoped
    layout "teacher"

    before_action :require_teacher!
    helper_method :current_teacher

    private

    def require_teacher!
      return if current_teacher
      redirect_to home_path_for_role(current_membership&.role),
                  alert: "Tài khoản này không phải giáo viên."
    end

    def current_teacher
      return @current_teacher if defined?(@current_teacher)
      @current_teacher = current_workspace && current_user &&
                         ::Teacher.find_by(workspace_id: current_workspace.id, user_id: current_user.id)
    end

    # Giáo viên chỉ thấy hồ mình được phân công dạy.
    def accessible_pools
      @accessible_pools ||= ActsAsTenant.with_tenant(current_workspace) do
        current_teacher ? current_teacher.pools.order(:position, :name).to_a : []
      end
    end
  end
end
