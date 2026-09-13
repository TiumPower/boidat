module Customer
  # Cổng phụ huynh / học viên (S5). Người đăng nhập là Guardian, không phải User:
  # quét mã QR của hộ gia đình là vào thẳng (FR-401, OQ-02 — phiên không hết hạn,
  # admin thu hồi được bằng nút cấp lại QR), hoặc người lớn tự học đăng nhập bằng
  # số điện thoại + OTP.
  class BaseController < ApplicationController
    include TenantResolver

    layout "member"

    before_action :set_current_workspace
    before_action :canonical_customer_host
    before_action :enforce_workspace_access
    before_action -> { no_browser_cache if guardian_signed_in? }
    around_action :scope_tenant

    helper_method :current_workspace, :current_guardian, :current_household,
                  :guardian_signed_in?, :household_students, :can_view_payments?

    private

    # ---- Phiên đăng nhập của hộ gia đình -----------------------------------
    # Cookie ký riêng cho từng workspace (`hh_<workspace_id>`), lưu cả hộ và
    # người giám hộ đang dùng máy: một phụ huynh có con học ở hai trung tâm khác
    # nhau vẫn đăng nhập song song được.
    GUARDIAN_COOKIE_TTL = 1.year

    def cookie_key = "hh_#{current_workspace&.id}"

    def session_payload
      return @session_payload if defined?(@session_payload)
      raw = current_workspace && cookies.signed[cookie_key]
      @session_payload = raw.is_a?(Hash) ? raw.symbolize_keys : nil
    end

    def current_guardian
      return @current_guardian if defined?(@current_guardian)
      gid = session_payload&.dig(:g)
      @current_guardian = gid ? Guardian.where(workspace_id: current_workspace.id).find_by(id: gid) : nil
    end

    def current_household = current_guardian&.household

    def guardian_signed_in? = current_guardian.present?

    def sign_in_guardian(guardian)
      cookies.signed[cookie_key] = {
        value: { g: guardian.id, h: guardian.household_id },
        expires: guardian_session_expiry, httponly: true,
        secure: Rails.env.production?, same_site: :lax
      }
      guardian.update_column(:last_seen_at, Time.current)
      @current_guardian = guardian
    end

    # OQ-02: khách chốt phiên không hết hạn. Vẫn để cấu hình được phòng khi đổi ý.
    def guardian_session_expiry
      days = current_workspace&.setting("qr_session_days")
      days.present? ? days.to_i.days.from_now : GUARDIAN_COOKIE_TTL.from_now
    end

    def sign_out_guardian
      cookies.delete(cookie_key) if current_workspace
      @current_guardian = nil
    end

    def require_guardian!
      return if guardian_signed_in?
      session[:return_to] = request.fullpath if request.get?
      redirect_to member_login_path
    end

    # Học viên của hộ đang đăng nhập — mọi màn hình đều chỉ đọc trong phạm vi này.
    def household_students
      return Student.none unless current_household
      @household_students ||= current_household.students.order(:birthdate, :name)
    end

    # OQ-03 — người đưa đón không xem được lịch sử thanh toán của hộ.
    def can_view_payments? = current_guardian&.can_view_payments?

    def require_payment_access!
      return if can_view_payments?
      redirect_to member_root_path, alert: "Chỉ chủ gia đình mới xem được mục thanh toán."
    end

    # ---- Workspace ---------------------------------------------------------
    def set_current_workspace
      @current_workspace = resolve_workspace
    end

    def current_workspace = @current_workspace

    # Ở production giữ PWA trên đúng subdomain của trung tâm: quyền camera (dùng
    # để chụp ảnh khuôn mặt) và trạng thái PWA gắn với origin, tách ra hai host
    # là mất quyền đã cấp.
    def canonical_customer_host
      return unless Rails.env.production? && request.get?
      ws = @current_workspace
      return if ws&.subdomain.blank?
      return if ws.custom_domain.present? && request.host == ws.custom_domain
      target = "#{ws.subdomain}.#{PLATFORM_HOST}"
      return if request.host == target
      return unless request.host == PLATFORM_HOST || request.host.end_with?(".#{PLATFORM_HOST}")
      path = request.fullpath.sub(%r{\A/w/[^/]+}, "").presence || "/"
      redirect_to "https://#{target}#{path}", allow_other_host: true
    end

    def scope_tenant
      if @current_workspace
        ActsAsTenant.with_tenant(@current_workspace) { yield }
      else
        yield
      end
    end

    def enforce_workspace_access
      return unless @current_workspace&.access_blocked?
      render "customer/shared/unavailable", layout: "member", status: :forbidden
    end

    def require_workspace!
      redirect_to root_path, alert: "Không tìm thấy trung tâm." unless current_workspace
    end

    # Chỉ giữ /w/:slug trong URL khi ta vào bằng đường dẫn đó (dev).
    def default_url_options
      params[:workspace_slug].present? ? { workspace_slug: params[:workspace_slug] } : {}
    end
  end
end
