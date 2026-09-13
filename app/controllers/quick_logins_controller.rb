# QR đăng nhập nhanh cho nhân sự (UX quầy điểm danh, màn 1): mở hồ sơ cá nhân
# trên web, quét mã bằng điện thoại là vào thẳng ca trực, không phải gõ mật khẩu
# trên bàn phím ảo giữa lúc đông khách. Mã có hạn 5 phút (User::QUICK_LOGIN_TTL).
class QuickLoginsController < ApplicationController
  include Devise::Controllers::Rememberable

  def show
    user = User.find_by_quick_login_token(params[:token])
    if user.nil?
      redirect_to new_user_session_path, alert: "Mã đăng nhập đã hết hạn. Vui lòng lấy mã mới."
      return
    end

    sign_in(user)
    remember_me(user)
    ws = user.workspaces.order(:created_at).first
    redirect_to home_path_for_role(user.role_in(ws)), notice: "Xin chào #{user.name}."
  end
end
