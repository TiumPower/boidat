module Customer
  class HomeController < BaseController
    def show
      if current_workspace.nil?
        # Host trần (chưa xác định được trung tâm) → trang launcher/marketing.
        @workspaces = Workspace.order(:name).to_a
        render "customer/home/landing", layout: "marketing"
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
