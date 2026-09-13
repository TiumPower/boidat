class Message < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[staff guardian].freeze

  belongs_to :workspace
  belongs_to :conversation
  belongs_to :user, optional: true
  belongs_to :guardian, optional: true

  validates :sender_kind, inclusion: { in: KINDS }
  validates :body, presence: true

  after_create_commit :broadcast!

  def from_staff? = sender_kind == "staff"
  def sender_name = from_staff? ? (user&.name || "Trung tâm") : (guardian&.name || "Phụ huynh")

  private

  def broadcast!
    broadcast_append_to conversation, target: "messages", partial: "shared/message",
                        locals: { message: self }
  rescue StandardError => e
    Rails.logger.warn("[chat] broadcast lỗi: #{e.class} #{e.message}")
  end
end
