module Merchant
  module Bod
    # Nhật ký thao tác toàn trung tâm (FR-116), lọc theo người dùng / hồ / hành
    # động / khoảng thời gian.
    class AuditLogsController < BaseController
      def index
        @logs = filtered_logs.includes(:user, :pool).recent.limit(300).to_a
        @users = current_workspace.users.order(:name).to_a
        @pools = accessible_pools
      end

      private

      def nav_key = :audit

      def filtered_logs
        scope = AuditLog.all
        scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
        scope = scope.where(pool_id: params[:pool_id]) if params[:pool_id].present?
        scope = scope.where(action: params[:action_kind]) if params[:action_kind].present?
        scope = scope.where("created_at >= ?", Date.parse(params[:from])) if params[:from].present?
        scope = scope.where("created_at <= ?", Date.parse(params[:to]).end_of_day) if params[:to].present?
        scope
      rescue ArgumentError
        AuditLog.all
      end
    end
  end
end
