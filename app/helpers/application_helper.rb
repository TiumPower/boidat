module ApplicationHelper
  # Workspace resolved purely from the request host — safe to call from Devise
  # controllers (login / password reset) where no tenant is set. Display-only.
  def host_workspace
    return @host_workspace if defined?(@host_workspace)
    sub = request.subdomains.first
    ws  = Workspace.find_by(subdomain: sub) if sub.present? &&
          !TenantResolver::RESERVED_SUBDOMAINS.include?(sub)
    @host_workspace = ws || Workspace.find_by(custom_domain: request.host)
  rescue StandardError
    @host_workspace = nil
  end

  # Icon/favicon URL for a workspace: the uploaded logo when present, else the
  # platform default. A proxy path (stable + cacheable), never a signed redirect.
  def workspace_icon_url(ws)
    if ws&.logo&.attached?
      rails_storage_proxy_path(ws.logo, only_path: true)
    else
      "/icon.png"
    end
  end

  # Workspace avatar: uploaded logo (cover-cropped) if present, else initials.
  def workspace_avatar(ws, klass: "avatar", style: nil)
    if ws&.logo&.attached?
      content_tag(:div,
                  image_tag(workspace_icon_url(ws), alt: "", style: "width:100%;height:100%;object-fit:cover;"),
                  class: klass, style: ["overflow:hidden", style].compact.join(";"))
    else
      content_tag(:div, ws&.logo_initials, class: klass, style: style)
    end
  end

  # VND money formatting: 1500000 → "1.500.000đ".
  def vnd(amount)
    "#{ActiveSupport::NumberHelper.number_to_delimited(amount.to_i)}đ"
  end

  # Phụ đề của mỗi màn đang mang theo mã yêu cầu trong SRS ("FR-206 · 14 em").
  # Rất tiện lúc nghiệm thu, nhưng trung tâm mua phần mềm thì không biết FR-206
  # là gì. Mặc định giấu, bật lại bằng SHOW_REQUIREMENT_CODES=true khi đi
  # nghiệm thu — không phải sửa 29 view.
  def show_requirement_codes? = ENV["SHOW_REQUIREMENT_CODES"] == "true"

  def page_subtitle(raw)
    text = raw.to_s.strip
    return text if show_requirement_codes?

    text.split("·").map(&:strip).reject { |part| part.blank? || part.match?(/\AFR-\d+\z/) }.join(" · ")
  end
end
