module Merchant
  module Ops
    # Sale tra bảng giá của hồ đang trực khi chốt lịch cho khách (chỉ đọc — quyền
    # sửa giá thuộc về BOD, OQ-20).
    class PackagesController < BaseController
      def index
        @packages = Package.active.ordered.includes(:course, :price_list_items).to_a
        @promotions = Promotion.active.ordered.select { |p| p.pool_id.nil? || p.pool_id == current_pool.id }
      end

      private

      def nav_key = :packages
    end
  end
end
