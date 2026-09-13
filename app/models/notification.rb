class Notification < ApplicationRecord
  acts_as_tenant(:workspace)

  # Người nhận có thể là Guardian (phụ huynh) hoặc User (giáo viên / admin).
  belongs_to :workspace
  belongs_to :recipient, polymorphic: true
  belongs_to :subject,   polymorphic: true, optional: true
  belongs_to :broadcast, optional: true

  ICONS = {
    "class_created"    => "🎉", "lesson_reminder" => "⏰", "feedback" => "📝",
    "invoice"          => "💳", "teacher_leave"   => "🔁", "low_sessions" => "⚠️",
    "face_photo"       => "📷", "payroll"         => "💰", "exam" => "🏅",
    "message"          => "💬", "system"          => "🔔"
  }.freeze

  scope :recent,   -> { order(created_at: :desc) }
  scope :unread,   -> { where(read_at: nil) }
  scope :pending_ack, -> { where(requires_ack: true, acknowledged_at: nil) }

  def read? = read_at.present?
  def acknowledged? = acknowledged_at.present?

  # OQ-16 — vì bỏ Zalo ZNS/SMS, admin phải nhìn thấy ai chưa xác nhận để gọi điện.
  def awaiting_ack? = requires_ack? && acknowledged_at.nil?

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def acknowledge!(choice = nil)
    update!(acknowledged_at: Time.current, ack_choice: choice, read_at: read_at || Time.current)
  end

  def display_icon = icon.presence || ICONS[kind] || "🔔"
end
