# Hồ bơi — trục phân quyền thứ hai (sau workspace). Mọi dữ liệu nghiệp vụ đều
# gắn với đúng một hồ; nhân sự chỉ thấy hồ mình được gán (FR-111, FR-112, FR-201).
class CreatePools < ActiveRecord::Migration[7.2]
  def change
    create_table :pools do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :name,    null: false
      t.string  :code                                  # Q7 / TD / GV — hiển thị gọn
      t.string  :address
      t.string  :phone
      t.string  :status,  null: false, default: "active" # active / paused / closed
      t.integer :position, null: false, default: 0
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
    end
    add_index :pools, [:workspace_id, :name]

    # Giờ mở cửa theo thứ trong tuần (FR-217). weekday: 0 = Chủ nhật.
    create_table :pool_operating_hours do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.integer :weekday,  null: false
      t.time    :opens_at
      t.time    :closes_at
      t.boolean :closed,   null: false, default: false
      t.timestamps
    end
    add_index :pool_operating_hours, [:pool_id, :weekday], unique: true

    # Ngày nghỉ lễ / bảo trì — chặn xếp lịch và sinh buổi học.
    create_table :pool_holidays do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.date   :date,   null: false
      t.string :reason
      t.timestamps
    end
    add_index :pool_holidays, [:pool_id, :date], unique: true

    # Gán nhân sự vào hồ (nhiều–nhiều). Gỡ gán KHÔNG xoá dữ liệu lịch sử.
    create_table :pool_assignments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :user,      null: false, foreign_key: true
      t.timestamps
    end
    add_index :pool_assignments, [:pool_id, :user_id], unique: true
  end
end
