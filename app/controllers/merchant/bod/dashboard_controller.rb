module Merchant
  module Bod
    # Bảng điều khiển tổng hợp (FR-101, FR-102, FR-104).
    class DashboardController < BaseController
      def show
        @scope_pool = params[:pool_id].presence
        @pools = accessible_pools
        @period = PeriodFilter.new(params[:period], params[:from], params[:to])

        metrics = PoolMetrics.new(workspace: current_workspace, pools: report_pools, period: @period)
        @stats = metrics.with_comparison
        @by_pool = metrics.by_pool
        @teachers = metrics.teacher_ranking
        @packages = metrics.package_ranking
        @series = metrics.revenue_series
        @tab = %w[teachers pools packages].include?(params[:tab]) ? params[:tab] : "teachers"
      end

      private

      def nav_key = :dashboard
    end
  end
end
