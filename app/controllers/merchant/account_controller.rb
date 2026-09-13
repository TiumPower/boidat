module Merchant
  # Hồ sơ cá nhân của nhân sự (FR-219): avatar, đổi mật khẩu, và mã QR đăng nhập
  # nhanh để mở PWA trên điện thoại (UX quầy điểm danh màn 1).
  class AccountController < BaseController
    def edit
      @user = current_user
    end

    def update
      @user = current_user
      if params.dig(:user, :password).present?
        if @user.update(password_params)
          bypass_sign_in(@user, scope: :user)
          redirect_to merchant_account_path, notice: "Đã đổi mật khẩu."
        else
          render :edit, status: :unprocessable_entity
        end
      elsif @user.update(account_params)
        redirect_to merchant_account_path, notice: "Đã cập nhật tài khoản."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Mã QR chỉ sống 5 phút và sinh lại mỗi lần mở trang — chụp màn hình gửi đi
    # thì cũng hết hạn trước khi dùng được.
    def qr
      @token = current_user.quick_login_token
      @url   = staff_quick_login_url(@token, host: request.host_with_port, protocol: request.protocol)
      render layout: false if request.headers["Turbo-Frame"].present?
    end

    private

    def account_params  = params.require(:user).permit(:name, :phone, :title, :locale, :avatar)
    def password_params = params.require(:user).permit(:password, :password_confirmation)
    def nav_key = :account
  end
end
