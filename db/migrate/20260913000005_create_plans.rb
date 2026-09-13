# Gói thuê bao của nền tảng (super admin bán cho từng trung tâm).
# Định giá theo quy mô: số hồ bơi và số học viên đang hoạt động.
class CreatePlans < ActiveRecord::Migration[7.2]
  def change
    create_table :plans do |t|
      t.string  :key,      null: false            # starter / pro / business
      t.string  :name,     null: false
      t.integer :price,    null: false, default: 0 # VND / tháng
      t.integer :position, null: false, default: 0

      t.integer :max_pools     # nil = không giới hạn
      t.integer :max_students
      t.integer :max_teachers

      t.boolean :allow_custom_domain, null: false, default: false
      t.boolean :allow_face_recognition, null: false, default: true
      t.boolean :allow_auto_scheduler,   null: false, default: true
      t.boolean :allow_chat,             null: false, default: true

      t.jsonb   :features, null: false, default: []

      t.timestamps
    end
    add_index :plans, :key, unique: true
  end
end
