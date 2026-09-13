module Pwa
  # Ba PWA khác nhau, ba manifest khác nhau — mỗi cái có `scope` riêng để khi
  # phụ huynh, giáo viên và lễ tân cùng cài lên một máy thì chúng không đè nhau.
  class ManifestsController < ApplicationController
    include TenantResolver
    skip_before_action :set_locale, raise: false

    # PWA phụ huynh / học viên (S5)
    def show
      ws = resolve_workspace
      start = customer_start_path(ws)
      render_manifest(
        name: ws&.name || "BƠI ĐẠT",
        description: ws&.branding_value("tagline") || "Trung tâm dạy bơi",
        start_url: start, scope: start, workspace: ws
      )
    end

    # PWA giáo viên (S4)
    def teacher
      ws = resolve_workspace
      render_manifest(name: ws ? "GV #{ws.name}" : "Cổng giáo viên",
                      description: "Lịch dạy, bảng công, nhận xét học viên",
                      start_url: "/teacher", scope: "/teacher", workspace: ws)
    end

    # PWA quầy điểm danh (S3)
    def desk
      ws = resolve_workspace
      render_manifest(name: ws ? "Điểm danh #{ws.name}" : "Quầy điểm danh",
                      description: "Quét khuôn mặt điểm danh tại quầy",
                      start_url: "/desk", scope: "/desk", workspace: ws)
    end

    private

    def render_manifest(name:, description:, start_url:, scope:, workspace:)
      theme = workspace&.theme_value("primary") || Workspace::DEFAULT_THEME["primary"]
      bg    = workspace&.theme_value("surface") || Workspace::DEFAULT_THEME["surface"]
      icon  = workspace_icon(workspace)
      render json: {
        name: name, short_name: name.to_s[0, 30], description: description,
        start_url: start_url, scope: scope, display: "standalone",
        background_color: bg, theme_color: theme,
        lang: workspace&.locale_default || "vi",
        icons: [
          { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
          { src: icon, sizes: "512x512", type: "image/png", purpose: "any" },
          { src: icon, sizes: "512x512", type: "image/png", purpose: "maskable" }
        ]
      }, content_type: "application/manifest+json"
    end

    def workspace_icon(ws)
      return "/icon.png" unless ws&.logo&.attached?
      Rails.application.routes.url_helpers.rails_storage_proxy_path(ws.logo, only_path: true)
    end

    def customer_start_path(ws)
      return "/" if ws.nil?
      Rails.env.production? && ws.subdomain.present? ? "/" : "/w/#{ws.slug}"
    end
  end
end
