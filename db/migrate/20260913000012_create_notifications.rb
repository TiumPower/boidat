# Thông báo in-app + Web Push. Người nhận là Guardian (phụ huynh) hoặc User
# (giáo viên / admin) nên dùng quan hệ đa hình.
class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :broadcasts do |t|
      t.references :workspace,  null: false, foreign_key: true
      t.references :pool,       null: true,  foreign_key: true
      t.references :created_by, null: true,  foreign_key: { to_table: :users }
      t.string   :segment_key, null: false, default: "all"
      t.string   :title, null: false
      t.text     :body
      t.integer  :sent_count, null: false, default: 0
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.timestamps
    end

    create_table :notifications do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :broadcast, null: true,  foreign_key: true
      t.references :recipient, null: false, polymorphic: true # Guardian / User
      t.string   :title, null: false
      t.text     :body
      # system / class_created / lesson_reminder / feedback / invoice / teacher_leave /
      # low_sessions / face_photo / payroll
      t.string   :kind,  null: false, default: "system"
      t.string   :icon
      t.string   :deep_link
      t.references :subject, null: true, polymorphic: true     # buổi học / đơn hàng / đơn nghỉ…
      t.boolean  :requires_ack, null: false, default: false     # OQ-16 — phải xác nhận
      t.datetime :read_at
      t.datetime :acknowledged_at
      t.string   :ack_choice                                    # follow_teacher / other_slot / …
      t.timestamps
    end
    add_index :notifications, [:recipient_type, :recipient_id, :read_at],
              name: "index_notifications_on_recipient_and_read"
    add_index :notifications, [:workspace_id, :requires_ack, :acknowledged_at],
              name: "index_notifications_on_ack_tracking"
  end
end
