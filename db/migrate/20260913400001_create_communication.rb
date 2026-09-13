# Chat realtime giữa admin và phụ huynh (FR-224/407) và bản cam kết ký điện tử
# (FR-207).
class CreateCommunication < ActiveRecord::Migration[7.2]
  def change
    # Một hội thoại cho mỗi hộ gia đình tại một hồ — nhiều admin cùng hồ đều
    # thấy chung hộp thư này (FR-224).
    create_table :conversations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.integer  :staff_unread,    null: false, default: 0
      t.integer  :guardian_unread, null: false, default: 0
      t.datetime :last_message_at
      t.string   :last_preview
      t.timestamps
    end
    add_index :conversations, [:pool_id, :household_id], unique: true
    add_index :conversations, [:workspace_id, :last_message_at]

    create_table :messages do |t|
      t.references :workspace,    null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :user,     null: true, foreign_key: true   # admin gửi
      t.references :guardian, null: true, foreign_key: true   # phụ huynh gửi
      t.string :sender_kind, null: false, default: "staff"    # staff / guardian
      t.text   :body
      t.datetime :read_at
      t.timestamps
    end
    add_index :messages, [:conversation_id, :created_at]

    # Bản cam kết PDF đã ký (FR-207). Chữ ký vẽ tay KHÔNG phải chữ ký số theo
    # Luật Giao dịch điện tử — nó là bằng chứng điện tử, nên phải lưu kèm audit
    # trail (thời điểm, IP, thiết bị, mã băm SHA-256) để tăng giá trị chứng cứ
    # và phải nói rõ giới hạn này với khách (OQ-15).
    create_table :contracts do |t|
      t.references :workspace,  null: false, foreign_key: true
      t.references :pool,       null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.references :household,  null: false, foreign_key: true
      t.references :signed_by,  null: true,  foreign_key: { to_table: :users }
      t.string   :number, null: false
      t.string   :status, null: false, default: "draft" # draft / signed / void
      t.string   :guardian_name
      t.datetime :signed_at
      t.string   :sha256
      t.string   :ip
      t.string   :user_agent
      t.jsonb    :snapshot, null: false, default: {}     # số liệu chốt tại thời điểm ký
      t.timestamps
    end
    add_index :contracts, :number, unique: true
    add_index :contracts, [:workspace_id, :status]
  end
end
