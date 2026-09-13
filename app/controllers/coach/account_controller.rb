module Coach
  # Hồ sơ giáo viên + bật thông báo đẩy (FR-306).
  class AccountController < BaseController
    def edit
      @user = current_user
      @teacher = current_teacher
    end

    def update
      @user = current_user
      if params.dig(:user, :password).present?
        if @user.update(params.require(:user).permit(:password, :password_confirmation))
          bypass_sign_in(@user, scope: :user)
          redirect_to teacher_account_path, notice: "Đã đổi mật khẩu."
        else
          @teacher = current_teacher
          render :edit, status: :unprocessable_entity
        end
      elsif @user.update(params.require(:user).permit(:name, :phone, :avatar))
        redirect_to teacher_account_path, notice: "Đã cập nhật hồ sơ."
      else
        @teacher = current_teacher
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def nav_key = :account
  end
end
