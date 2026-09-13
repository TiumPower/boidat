module Merchant
  module Bod
    # Màu chủ đạo & thương hiệu — áp cho cả 5 cổng (đúng như dòng chữ trong bộ UX).
    class AppearanceController < BaseController
      def edit
        @workspace = current_workspace
      end

      def update
        ws = current_workspace
        if params[:preset].present?
          ws.apply_theme_preset!(params[:preset])
        else
          theme = ws.theme.merge(
            params.require(:theme).permit(:primary, :primary_2, :surface, :radius,
                                          :font_display, :font_body).to_h.compact_blank
          )
          ws.update!(theme: theme)
        end
        ws.update!(branding: ws.branding.merge(branding_params)) if params[:branding].present?
        ws.logo.attach(params[:logo]) if params[:logo].present?
        audit!("update", ws, summary: "Đổi giao diện")
        redirect_to merchant_bod_appearance_path, notice: "Đã áp dụng giao diện mới."
      end

      private

      def nav_key = :appearance

      def branding_params
        params.require(:branding).permit(:logo_text, :tagline, :city, :contact_phone).to_h
      end
    end
  end
end
