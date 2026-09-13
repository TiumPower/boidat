# Resolves the current Workspace (tenant) for the customer PWA from, in order:
#   1. an explicit /w/:workspace_slug path segment (dev fallback)
#   2. a custom domain host   (e.g. loyalty.tenshop.vn)
#   3. a shop subdomain        (e.g. tenshop.loyalty.vn / tenshop.lvh.me)
# Reserved subdomains (app, admin, www, api) never resolve to a shop.
module TenantResolver
  extend ActiveSupport::Concern

  RESERVED_SUBDOMAINS = %w[app admin www api assets].freeze

  private

  def resolve_workspace
    by_slug || by_custom_domain || by_subdomain
  end

  # Chấp nhận cả slug lẫn subdomain trong đoạn /w/:x — ở production trung tâm
  # truy cập bằng subdomain, nên khi dán link dev người ta gõ theo subdomain là
  # phản xạ tự nhiên. Bắt họ nhớ hai chuỗi khác nhau chỉ tổ sinh lỗi 404 khó hiểu.
  def by_slug
    key = params[:workspace_slug]
    return nil if key.blank?
    Workspace.find_by(slug: key) || Workspace.find_by(subdomain: key)
  end

  def by_custom_domain
    Workspace.find_by(custom_domain: request.host)
  end

  def by_subdomain
    sub = request.subdomains.first
    return nil if sub.blank? || RESERVED_SUBDOMAINS.include?(sub)
    Workspace.find_by(subdomain: sub)
  end
end
