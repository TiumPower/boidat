# Nhật ký thao tác (FR-221, FR-116). Chỉ ghi thao tác GHI/SỬA/XOÁ và các lần đọc
# dữ liệu nhạy cảm (thanh toán, ảnh khuôn mặt) — OQ-19, giữ 12 tháng rồi archive.
class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: true,  foreign_key: true
      t.references :user,      null: true,  foreign_key: true
      t.string  :actor_label                       # giữ tên kể cả khi user bị xoá
      t.string  :action,      null: false          # create / update / destroy / read_sensitive
      t.string  :entity_type, null: false
      t.bigint  :entity_id
      t.string  :summary
      t.jsonb   :changes_before, null: false, default: {}
      t.jsonb   :changes_after,  null: false, default: {}
      t.string  :ip
      t.string  :user_agent
      t.timestamps
    end
    add_index :audit_logs, [:workspace_id, :created_at]
    add_index :audit_logs, [:entity_type, :entity_id]
    add_index :audit_logs, [:workspace_id, :user_id, :created_at],
              name: "index_audit_logs_on_workspace_user_time"
  end
end
