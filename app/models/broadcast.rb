# Thông báo hàng loạt do admin gửi cho phụ huynh của một hồ.
class Broadcast < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :pool, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :notifications, dependent: :nullify

  validates :title, :body, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :due, -> { where(sent_at: nil).where.not(scheduled_at: nil).where("scheduled_at <= ?", Time.current) }

  def scheduled? = scheduled_at.present? && sent_at.nil?

  def deliver!(guardians)
    now = Time.current
    rows = guardians.map do |g|
      { workspace_id: workspace_id, recipient_type: "Guardian", recipient_id: g.id,
        broadcast_id: id, title: title, body: body, kind: "message",
        created_at: now, updated_at: now }
    end
    Notification.insert_all(rows) if rows.any?
    update!(sent_count: rows.size, sent_at: now)
    PushJob.perform_later(workspace_id, "Guardian", guardians.map(&:id), title, body.to_s, "/notifications") if rows.any?
  end
end
