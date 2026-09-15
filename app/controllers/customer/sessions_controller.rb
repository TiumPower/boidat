module Customer
  # Một cách duy nhất vào cổng phụ huynh (FR-401): quét mã QR cá nhân của người
  # giám hộ. Không cần mật khẩu, phiên không hết hạn.
  #
  # Mã là của TỪNG NGƯỜI chứ không phải của cả hộ: chủ hộ và người đưa đón có
  # quyền khác nhau (OQ-03) nên phải phân biệt được ai đang quét. Người lớn tự
  # học cũng là một Guardian và có mã riêng của mình.
  #
  # Từng có lối thứ hai bằng SĐT + OTP, đã gỡ: giai đoạn 1 chưa nối SMS/Zalo
  # (phụ thuộc A5) nên mã chỉ được ghi vào log máy chủ, trong khi màn hình báo
  # với phụ huynh là "Mã 6 số đã gửi tới …". Họ đợi một thứ không bao giờ tới,
  # và admin trung tâm không có quyền đọc log để đọc mã cho họ. Một ngõ cụt
  # bày ngang hàng với lối đi thật thì tệ hơn là không bày.
  class SessionsController < BaseController
    before_action :require_workspace!, except: [:destroy]

    def new
      redirect_to(member_root_path) and return if guardian_signed_in?
    end

    # Dán mã QR (hoặc dán nguyên đường dẫn chép từ tin nhắn).
    def create
      token = extract_token(params[:qr_token])
      guardian  = Guardian.find_by(qr_token: token) if token.present?
      household = Household.find_by(qr_token: token) if token.present? && guardian.nil?

      if guardian&.qr_active?
        sign_in_guardian_and_go(guardian)
      elsif household&.qr_active?
        sign_in_household(household)
      else
        flash.now[:alert] = "Mã QR không hợp lệ hoặc đã bị thu hồi. Liên hệ trung tâm để cấp lại."
        render :new, status: :unprocessable_entity
      end
    end

    # Quét QR trực tiếp bằng camera → điều hướng tới /q/:token.
    # Mã QR là của TỪNG NGƯỜI giám hộ. Trước đây một hộ chỉ có một mã, và ai
    # quét cũng được đăng nhập thành chủ hộ — nên người đưa đón cầm đúng mã ấy
    # là đọc được toàn bộ hoá đơn, khiến OQ-03 chỉ còn là cái nhãn trên màn hình.
    # Mã của hộ vẫn nhận, để những link đã phát ra không chết, và nó dẫn về chủ hộ.
    def qr
      guardian = Guardian.find_by(qr_token: params[:qr_token])
      if guardian
        return redirect_to(member_login_path, alert: "Mã QR đã bị thu hồi.") unless guardian.qr_active?
        return sign_in_guardian_and_go(guardian)
      end

      household = Household.find_by(qr_token: params[:qr_token])
      if household&.qr_active?
        sign_in_household(household)
      else
        redirect_to member_login_path, alert: "Mã QR không hợp lệ hoặc đã bị thu hồi."
      end
    end

    def destroy
      sign_out_guardian
      redirect_to member_login_path, notice: "Đã đăng xuất."
    end

    private

    # Mã cũ ở cấp hộ vẫn dùng được để link đã phát ra không chết; nó dẫn về chủ hộ.
    def sign_in_household(household)
      guardian = household.owner
      if guardian.nil?
        return redirect_to(member_login_path, alert: "Hộ gia đình này chưa có người giám hộ.")
      end
      sign_in_guardian_and_go(guardian)
    end

    def sign_in_guardian_and_go(guardian)
      sign_in_guardian(guardian)
      redirect_to (session.delete(:return_to).presence || member_root_path),
                  notice: "Chào #{guardian.name} 👋"
    end

    # Chấp nhận cả mã trần lẫn URL đầy đủ dán từ tin nhắn.
    def extract_token(value)
      v = value.to_s.strip
      v = v.split("/q/").last if v.include?("/q/")
      v.split(/[?#]/).first
    end

  end
end
