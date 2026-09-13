# Hộp thư giữa hộ gia đình và admin của hồ (FR-224/407).
# Một hội thoại cho mỗi hộ × hồ — nhiều admin cùng hồ đều thấy chung.
class Conversation < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :pool
  belongs_to :household
  has_many :messages, -> { order(:created_at) }, dependent: :destroy

  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }
  scope :unread_for_staff, -> { where("staff_unread > 0") }

  def self.for_household(household, pool)
    find_or_create_by!(workspace: household.workspace, household: household, pool: pool)
  end

  def post!(sender_kind:, body:, user: nil, guardian: nil)
    message = messages.create!(workspace: workspace, sender_kind: sender_kind, body: body,
                               user: user, guardian: guardian)
    if sender_kind == "staff"
      increment!(:guardian_unread)
    else
      increment!(:staff_unread)
    end
    update!(last_message_at: message.created_at, last_preview: body.to_s.truncate(80))
    broadcast_badges!
    message
  end

  def mark_read_by_staff! = update!(staff_unread: 0)
  def mark_read_by_guardian! = update!(guardian_unread: 0)

  def title = household.name

  private

  # Cập nhật badge chưa đọc realtime. Lỗi cable không được phép làm hỏng request
  # — tin nhắn đã lưu rồi, badge chỉ là trang trí.
  def broadcast_badges!
    Turbo::StreamsChannel.broadcast_replace_to(
      workspace, "staff_chat_badge", target: "staff_chat_badge",
      partial: "layouts/chat_tab_badge",
      locals: { count: workspace.conversations.sum(:staff_unread) }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      self, "guardian_badge", target: "chat_tab_badge",
      partial: "layouts/chat_tab_badge", locals: { count: guardian_unread }
    )
  rescue StandardError => e
    Rails.logger.warn("[chat] broadcast lỗi: #{e.class} #{e.message}")
  end
end
