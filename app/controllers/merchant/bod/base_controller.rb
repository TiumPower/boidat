module Merchant
  module Bod
    class BaseController < Merchant::BaseController
      before_action :require_executive!

      private

      # BOD nhìn toàn bộ hồ chứ không chỉ hồ đang chọn — bộ lọc phạm vi nằm ngay
      # trên dashboard ("Tất cả hồ" hoặc một hồ cụ thể, FR-101).
      def report_pools
        return [current_pool].compact if params[:pool_id].present? && params[:pool_id] != "all"
        accessible_pools
      end
      helper_method :report_pools
    end
  end
end
