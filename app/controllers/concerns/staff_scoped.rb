# Hai trục phân quyền của hệ thống, dùng chung cho cả ba cổng của nhân sự
# (back office /merchant, quầy điểm danh /desk, PWA giáo viên /teacher):
#
#   1. Workspace — trung tâm (acts_as_tenant, row-level workspace_id).
#   2. Pool      — hồ bơi. Mỗi truy vấn nghiệp vụ đều lọc theo danh sách hồ mà
#                  người dùng được gán (FR-112, FR-201). BOD thấy tất cả các hồ.
#
# Đây là nền móng bắt buộc, không thể bổ sung sau: nếu một controller quên gọi
# `current_pool`, dữ liệu hồ khác sẽ lọt ra ngoài.
module StaffScoped
  extend ActiveSupport::Concern

  included do
    before_action :require_staff!
    before_action :no_browser_cache
    before_action :set_current_workspace
    before_action :require_accessible_workspace
    before_action :enforce_workspace_access
    before_action :set_current_pool
    around_action :scope_tenant

    helper_method :current_workspace, :current_membership, :current_pool,
                  :accessible_pools, :accessible_workspaces, :nav_key,
                  :feature_locked?, :impersonating?, :staff_chat_unread
  end

  private

  def require_staff!
    return if user_signed_in?
    redirect_to new_user_session_path, alert: "Vui lòng đăng nhập."
  end

  def impersonating? = session[:impersonator_admin_id].present?

  def accessible_workspaces
    @accessible_workspaces ||= current_user ? current_user.workspaces.order(:created_at).to_a : []
  end

  def current_workspace = @current_workspace

  def set_current_workspace
    return unless current_user
    host_ws = workspace_from_host
    if host_ws && accessible_workspaces.any? { |w| w.id == host_ws.id }
      @current_workspace = host_ws
    elsif session[:workspace_id].present?
      @current_workspace = accessible_workspaces.find { |w| w.id == session[:workspace_id].to_i }
    end
    @current_workspace ||= accessible_workspaces.first
    session[:workspace_id] = @current_workspace&.id
  end

  def require_accessible_workspace
    return if @current_workspace
    sign_out(current_user)
    redirect_to new_user_session_path,
                alert: "Tài khoản này chưa được gán vào trung tâm nào. Vui lòng đăng nhập lại."
  end

  def workspace_from_host
    sub = request.subdomains.first
    ws = Workspace.find_by(subdomain: sub) unless sub.blank? || TenantResolver::RESERVED_SUBDOMAINS.include?(sub)
    ws || Workspace.find_by(custom_domain: request.host)
  end

  def scope_tenant
    if @current_workspace
      ActsAsTenant.with_tenant(@current_workspace) { yield }
    else
      yield
    end
  end

  # Trung tâm bị khoá (quá hạn thuê bao) thì back office đóng, trừ trang thanh toán.
  def enforce_workspace_access
    return unless @current_workspace
    @block_reason = @current_workspace.access_blocked_reason
    return unless @block_reason
    return if @block_reason == :unpaid && controller_name == "subscription"
    render "merchant/shared/locked", layout: "auth", status: :forbidden
  end

  def current_membership
    return nil unless current_user && current_workspace
    @current_membership ||= current_user.membership_for(current_workspace)
  end

  # Hồ mà người dùng hiện tại được phép xem/thao tác.
  def accessible_pools
    @accessible_pools ||= ActsAsTenant.with_tenant(current_workspace) do
      current_user.accessible_pools(current_workspace).to_a
    end
  end

  # Hồ đang chọn — ghi nhớ giữa các phiên (FR-201).
  def current_pool = @current_pool

  def set_current_pool
    return unless current_workspace
    wanted = session[:pool_id].to_i
    @current_pool = accessible_pools.find { |p| p.id == wanted } || accessible_pools.first
    session[:pool_id] = @current_pool&.id
  end

  def switch_pool!(pool_id)
    pool = accessible_pools.find { |p| p.id == pool_id.to_i }
    return false unless pool
    session[:pool_id] = pool.id
    @current_pool = pool
    true
  end

  def require_pool!
    return if current_pool
    redirect_to merchant_root_path, alert: "Tài khoản của bạn chưa được gán hồ bơi nào."
  end

  # Học viên / lớp / buổi học của hồ đang chọn. Mọi controller nghiệp vụ đọc dữ
  # liệu qua đây thay vì gọi thẳng model, để không quên lọc theo hồ.
  def pool_scope(relation)
    return relation.none unless current_pool
    relation.where(pool_id: current_pool.id)
  end

  def feature_locked?(feature) = current_workspace && !current_workspace.plan_allows?(feature)

  # Badge tin chưa đọc trên sidebar — đếm theo hồ đang chọn, vì hộp thư là của hồ.
  def staff_chat_unread
    return 0 unless current_pool
    @staff_chat_unread ||= Conversation.where(pool_id: current_pool.id).sum(:staff_unread)
  end

  def require_role!(*roles)
    return if current_membership && roles.map(&:to_s).include?(current_membership.role)
    redirect_to merchant_root_path, alert: "Bạn không có quyền vào mục này."
  end

  # Ghi nhật ký thao tác (FR-221). Gọi ở mọi hành động ghi/sửa/xoá.
  def audit!(action, entity, summary: nil, before: nil, after: nil)
    AuditLog.record!(action: action, entity: entity, user: current_user, pool: current_pool,
                     summary: summary, before: before, after: after, request: request)
  end

  def nav_key = nil
end
