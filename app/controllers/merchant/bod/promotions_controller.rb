module Merchant
  module Bod
    # Khuyến mãi (OQ-17 — list gốc của khách không có gì phục vụ marketing,
    # đây là phần đội triển khai bổ sung, nhỏ nhưng giá trị cao).
    class PromotionsController < BaseController
      before_action :set_promotion, only: [:edit, :update, :destroy]

      def index
        @promotions = Promotion.ordered.includes(:pool).to_a
      end

      def new
        @promotion = Promotion.new(workspace: current_workspace, kind: "bonus_sessions", status: "active")
      end

      def create
        @promotion = Promotion.new(promotion_params.merge(workspace: current_workspace))
        if @promotion.save
          audit!("create", @promotion, summary: "Tạo khuyến mãi #{@promotion.name}")
          redirect_to merchant_bod_promotions_path, notice: "Đã tạo khuyến mãi."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @promotion.update(promotion_params)
          audit!("update", @promotion, summary: "Sửa khuyến mãi #{@promotion.name}")
          redirect_to merchant_bod_promotions_path, notice: "Đã lưu."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        audit!("destroy", @promotion, summary: "Xoá khuyến mãi #{@promotion.name}")
        @promotion.destroy
        redirect_to merchant_bod_promotions_path, notice: "Đã xoá."
      end

      private

      def nav_key = :packages
      def set_promotion = @promotion = Promotion.find(params[:id])

      def promotion_params
        params.require(:promotion).permit(:name, :kind, :value, :condition_note, :stock,
                                          :status, :starts_on, :ends_on, :pool_id)
      end
    end
  end
end
