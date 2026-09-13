# Đăng nhập của nhân sự: email + mật khẩu do Admin đặt (FR-218). Không có luồng
# tự đăng ký. Sau khi vào, mỗi vai trò được đưa thẳng tới cổng của mình.
class Users::SessionsController < Devise::SessionsController
  layout "auth"

  def create
    super do |user|
      AuditLog.record!(action: "login", entity: user.workspaces.first || user,
                       user: user, summary: "Đăng nhập", request: request) if user.persisted?
    end
  end
end
