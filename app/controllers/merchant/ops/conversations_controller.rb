module Merchant
  module Ops
    # Hộp thư chat của Admin (FR-224): danh sách hội thoại với từng hộ gia đình,
    # lọc theo hồ đang chọn, đánh dấu chưa đọc. Nhiều admin cùng một hồ đều thấy
    # chung hộp thư này.
    class ConversationsController < BaseController
      def index
        @q = params[:q].to_s.strip
        scope = Conversation.where(pool_id: current_pool.id).includes(household: :students)
        if @q.present?
          scope = scope.where(household_id: Household.where("households.name ILIKE :q", q: "%#{@q}%")
                                                     .or(Household.where(id: Student.where("students.name ILIKE :q", q: "%#{@q}%").select(:household_id))))
        end
        @conversations = scope.recent.limit(100).to_a
        @unread_total = Conversation.where(pool_id: current_pool.id).sum(:staff_unread)
      end

      def show
        @conversation = Conversation.where(pool_id: current_pool.id).find(params[:id])
        @messages = @conversation.messages.includes(:user, :guardian).to_a
        @conversation.mark_read_by_staff!
        @conversations = Conversation.where(pool_id: current_pool.id).recent.limit(50).to_a
      end

      private

      def nav_key = :chat
    end
  end
end
