module Admin
  class AccountController < BaseController
    def edit
      @admin = current_admin_user
    end

    def update
      @admin = current_admin_user
      attrs = params.require(:admin_user).permit(:name, :email, :password, :password_confirmation)
      attrs.delete(:password) if attrs[:password].blank?
      attrs.delete(:password_confirmation) if attrs[:password_confirmation].blank?
      if attrs[:password].present? ? @admin.update(attrs) : @admin.update(attrs.except(:password, :password_confirmation))
        bypass_sign_in(@admin)
        redirect_to admin_account_path, notice: "Đã cập nhật hồ sơ."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def nav_key = :account
  end
end
