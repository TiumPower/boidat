# Giáo viên + cấp độ. Level quyết định số học viên tối đa dạy cùng lúc (BR-04),
# và đơn giá quy đổi công → tiền (OQ-18).
class CreateTeachers < ActiveRecord::Migration[7.2]
  def change
    create_table :teacher_levels do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :name, null: false                      # Level 1..4
      t.integer :position, null: false, default: 0
      t.integer :max_students_per_slot, null: false, default: 2
      t.integer :pay_rate_per_credit,   null: false, default: 0 # VND / công
      t.text    :description
      t.timestamps
    end
    add_index :teacher_levels, [:workspace_id, :name], unique: true

    create_table :teachers do |t|
      t.references :workspace,     null: false, foreign_key: true
      t.references :user,          null: false, foreign_key: true
      t.references :teacher_level, null: true,  foreign_key: true
      # staff  = giáo viên thuộc trung tâm (đủ nghiệp vụ)
      # renter = giáo viên thuê hồ, tự dạy học viên của họ (FR-225, luồng rút gọn)
      t.string  :kind,   null: false, default: "staff"
      t.string  :status, null: false, default: "active" # active / on_leave / inactive
      t.string  :specialty                              # "trẻ em sợ nước", "bơi ếch"…
      t.integer :years_experience
      t.text    :bio                                    # mô tả hiển thị cho phụ huynh (FR-209)
      t.string  :org_name                               # CLB Cá Heo — với giáo viên thuê hồ
      t.timestamps
    end
    add_index :teachers, [:workspace_id, :user_id], unique: true
    add_index :teachers, [:workspace_id, :kind]

    create_table :teacher_pools do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :teacher,   null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.timestamps
    end
    add_index :teacher_pools, [:teacher_id, :pool_id], unique: true
  end
end
