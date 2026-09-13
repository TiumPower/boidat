module Merchant
  module Ops
    class AuditLogsController < BaseController
      def index
        @logs = AuditLog.where(pool_id: current_pool.id).includes(:user).recent.limit(200).to_a
      end

      private

      def nav_key = :audit
    end
  end
end
