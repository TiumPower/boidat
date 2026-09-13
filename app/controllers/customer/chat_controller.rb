module Customer
  # Chat realtime với admin của hồ (FR-407).
  class ChatController < BaseController
    before_action :require_guardian!
    before_action :set_conversation

    def show
      @messages = @conversation.messages.includes(:user, :guardian).to_a
      @conversation.mark_read_by_guardian!
    end

    # Fallback polling cho proxy không nâng cấp WebSocket — cùng cách estate làm.
    def updates
      after = params[:after].to_i
      messages = @conversation.messages.where("id > ?", after).to_a
      render json: messages.map { |m|
        { id: m.id, body: m.body, mine: m.sender_kind == "guardian",
          sender: m.sender_name, at: l(m.created_at, format: "%H:%M") }
      }
    end

    def create_message
      body = params[:body].to_s.strip
      if body.present?
        @conversation.post!(sender_kind: "guardian", body: body, guardian: current_guardian)
        notify_staff(body)
      end
      redirect_to member_chat_path
    end

    private

    def set_conversation
      pool = current_household.students.first&.pool || current_workspace.pools.first
      return redirect_to(member_root_path, alert: "Chưa có hồ bơi nào để nhắn tin.") if pool.nil?
      @conversation = Conversation.for_household(current_household, pool)
    end

    def notify_staff(body)
      staff = User.where(id: PoolAssignment.where(pool_id: @conversation.pool_id).select(:user_id))
                  .where(id: current_workspace.memberships.where(role: %w[admin bod sale]).select(:user_id))
      return if staff.empty?
      PushJob.perform_later(current_workspace.id, "User", staff.pluck(:id),
                            "Tin nhắn từ #{current_household.name}", body.truncate(80),
                            "/merchant/ops/conversations")
    end
  end
end
