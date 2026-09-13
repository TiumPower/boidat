# Đơn xin nghỉ của giáo viên (FR-305) → Admin duyệt (FR-211) → thông báo cho
# học viên của các buổi bị ảnh hưởng → phụ huynh chọn phương án học bù.
class CreateLeaveRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :leave_requests do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :teacher,   null: false, foreign_key: true
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.bigint  :lesson_ids, array: true, null: false, default: []
      t.text    :reason
      t.string  :status, null: false, default: "pending" # pending / approved / rejected
      t.text    :review_note
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :leave_requests, [:workspace_id, :status]
    add_index :leave_requests, :lesson_ids, using: :gin
  end
end
