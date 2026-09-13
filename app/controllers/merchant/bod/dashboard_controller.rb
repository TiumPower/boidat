module Merchant
  module Bod
    # Bảng điều khiển tổng hợp (FR-101, FR-102). P0 dựng khung + các chỉ số tính
    # được từ dữ liệu đã có; doanh thu / công / tỷ lệ lấp đầy nối vào ở P3–P6.
    class DashboardController < BaseController
      def show
        @scope_pool = params[:pool_id].presence
        @pools = accessible_pools
        @period = PeriodFilter.new(params[:period], params[:from], params[:to])

        pool_ids = report_pools.map(&:id)
        @stats = {
          students: Student.where(pool_id: pool_ids, status: "active").count,
          new_students: Student.where(pool_id: pool_ids, created_at: @period.range).count,
          teachers: ::Teacher.staff.active.count,
          pools: @pools.size
        }
      end

      private

      def nav_key = :dashboard
    end
  end
end
