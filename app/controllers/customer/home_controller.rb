module Customer
  class HomeController < BaseController
    def show
      if current_workspace.nil?
        # Host trần (chưa xác định được trung tâm) → bảng chọn cổng. Không có
        # trang giới thiệu: khung marketing cũ là của Estate (logo chung cư,
        # "Tìm phòng", ba nút 404) nên đã gỡ hẳn thay vì vá.
        @workspaces = Workspace.order(:name).to_a
        render "customer/home/landing", layout: "launcher"
      elsif !guardian_signed_in?
        redirect_to member_login_path
      else
        @household = current_household
        @students  = household_students.includes(:pool, :face_profile)
        @needs_face = @students.reject(&:face_registered?)
        @unread = Notification.where(recipient: current_guardian, read_at: nil).count
        render :show
      end
    end
  end
end
