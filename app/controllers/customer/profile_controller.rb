module Customer
  # Hồ sơ phụ huynh, mã QR của hộ, và quyền xoá dữ liệu sinh trắc học (FR-409).
  class ProfileController < BaseController
    before_action :require_guardian!

    def show
      @guardian = current_guardian
      @household = current_household
      @students = household_students.includes(:face_profile)
      @qr_url = member_qr_login_url(qr_token: @household.qr_token, host: request.host_with_port,
                                    protocol: request.protocol,
                                    workspace_slug: params[:workspace_slug])
    end

    def update
      if current_guardian.update(params.require(:guardian).permit(:name, :phone, :email))
        redirect_to member_profile_path, notice: "Đã cập nhật hồ sơ."
      else
        @guardian = current_guardian
        @household = current_household
        @students = household_students
        render :show, status: :unprocessable_entity
      end
    end
  end
end
