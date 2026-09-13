# Web Push cho cả 3 PWA (phụ huynh, giáo viên, quầy điểm danh).
class CreatePushSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :push_subscriptions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :guardian,  null: true,  foreign_key: true
      t.references :user,      null: true,  foreign_key: true
      t.string :endpoint, null: false
      t.string :p256dh,   null: false
      t.string :auth,     null: false
      t.timestamps
    end
    add_index :push_subscriptions, [:guardian_id, :endpoint], unique: true, where: "guardian_id IS NOT NULL"
    add_index :push_subscriptions, [:user_id, :endpoint],     unique: true, where: "user_id IS NOT NULL"
  end
end
