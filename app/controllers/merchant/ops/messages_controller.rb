module Merchant
  module Ops
    class MessagesController < BaseController
      def create
        conversation = Conversation.where(pool_id: current_pool.id).find(params[:conversation_id])
        body = params[:body].to_s.strip
        if body.present?
          conversation.post!(sender_kind: "staff", body: body, user: current_user)
          notify_guardians(conversation, body)
        end
        redirect_to merchant_ops_conversation_path(conversation)
      end

      private

      def nav_key = :chat

      def notify_guardians(conversation, body)
        guardians = conversation.household.guardians.to_a
        return if guardians.empty?
        PushJob.perform_later(current_workspace.id, "Guardian", guardians.map(&:id),
                              "Tin nhắn từ #{current_pool.name}", body.truncate(80), "/chat")
      end
    end
  end
end
