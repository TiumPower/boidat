module Merchant
  module Bod
    # Một dòng bảng giá. Giá có hiệu lực theo thời gian nên tăng giá không làm
    # sai lệch các đơn đã bán trước đó.
    class PriceListItemsController < BaseController
      before_action :set_package

      def create
        item = @package.price_list_items.new(item_params.merge(workspace: current_workspace))
        if item.save
          audit!("create", item, summary: "Đặt giá #{item.scope_label} cho gói #{@package.name}")
          redirect_to merchant_bod_package_path(@package), notice: "Đã thêm giá."
        else
          redirect_to merchant_bod_package_path(@package), alert: item.errors.full_messages.to_sentence
        end
      end

      def destroy
        item = @package.price_list_items.find(params[:id])
        audit!("destroy", item, summary: "Xoá dòng giá của gói #{@package.name}")
        item.destroy
        redirect_to merchant_bod_package_path(@package), notice: "Đã xoá dòng giá."
      end

      private

      def nav_key = :packages
      def set_package = @package = Package.find(params[:package_id])

      def item_params
        params.require(:price_list_item).permit(:pool_id, :price, :effective_from, :effective_to)
      end
    end
  end
end
