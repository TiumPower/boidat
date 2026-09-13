module Customer
  # Hai cách vào cổng phụ huynh (FR-401, UX phụ huynh màn 1):
  #   1. Quét mã QR của hộ gia đình — không cần mật khẩu, phiên không hết hạn.
  #   2. Người lớn tự học: số điện thoại + OTP.
  class SessionsController < BaseController
    before_action :require_workspace!, except: [:destroy]

    def new
      redirect_to(member_root_path) and return if guardian_signed_in?
      @mode = params[:mode] == "phone" ? "phone" : "qr"
      @phone = ""
    end

    # Nhập/dán mã QR hoặc gửi OTP cho số điện thoại.
    def create
      if params[:mode] == "phone"
        start_phone_login
      else
        token = extract_token(params[:qr_token])
        household = Household.find_by(qr_token: token) if token.present?
        if household&.qr_active?
          sign_in_household(household)
        else
          flash.now[:alert] = "Mã QR không hợp lệ hoặc đã bị thu hồi. Liên hệ trung tâm để cấp lại."
          @mode = "qr"
          render :new, status: :unprocessable_entity
        end
      end
    end

    # Quét QR trực tiếp bằng camera → điều hướng tới /q/:token.
    def qr
      household = Household.find_by(qr_token: params[:qr_token])
      if household&.qr_active?
        sign_in_household(household)
      else
        redirect_to member_login_path, alert: "Mã QR không hợp lệ hoặc đã bị thu hồi."
      end
    end

    def verify_form
      @phone = session[:otp_phone]
      redirect_to(member_login_path) and return if @phone.blank?
      @dev_code = latest_code(@phone) if show_otp_onscreen?
    end

    def verify
      @phone = session[:otp_phone]
      redirect_to(member_login_path) and return if @phone.blank?

      challenge = OtpChallenge.latest_for(identity: @phone, scope: "guardian", workspace: current_workspace)
      if challenge&.verify(params[:code]) == :ok
        guardian = Guardian.find_by(phone: Guardian.normalize_phone(@phone))
        session.delete(:otp_phone)
        if guardian
          sign_in_guardian(guardian)
          redirect_to (session.delete(:return_to).presence || member_root_path),
                      notice: "Chào #{guardian.name} 👋"
        else
          redirect_to member_login_path, alert: "Số điện thoại này chưa đăng ký học viên nào."
        end
      else
        @dev_code = latest_code(@phone) if show_otp_onscreen?
        flash.now[:alert] = "Mã xác thực không đúng hoặc đã hết hạn."
        render :verify_form, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out_guardian
      redirect_to member_login_path, notice: "Đã đăng xuất."
    end

    private

    def start_phone_login
      @phone = Guardian.normalize_phone(params[:phone])
      if @phone.length < 9
        @mode = "phone"
        flash.now[:alert] = "Số điện thoại không hợp lệ."
        return render(:new, status: :unprocessable_entity)
      end
      OtpChallenge.issue!(identity: @phone, scope: "guardian", workspace: current_workspace)
      session[:otp_phone] = @phone
      redirect_to member_verify_path
    end

    # Ai cầm QR cũng vào được (OQ-02) — phiên gắn với chủ hộ của hộ đó.
    def sign_in_household(household)
      guardian = household.owner
      if guardian.nil?
        return redirect_to(member_login_path, alert: "Hộ gia đình này chưa có người giám hộ.")
      end
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

    def show_otp_onscreen?
      ENV["SHOW_OTP"] == "true" || !Rails.env.production?
    end

    def latest_code(phone)
      OtpChallenge.latest_for(identity: phone, scope: "guardian", workspace: current_workspace)&.code
    end
  end
end
