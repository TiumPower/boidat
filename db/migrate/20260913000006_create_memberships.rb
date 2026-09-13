# Gắn một User (nhân sự) vào một Workspace kèm vai trò.
# Vai trò quyết định cổng vào nào mở ra cho người đó (§3.1 SRS).
class CreateMemberships < ActiveRecord::Migration[7.2]
  def change
    create_table :memberships do |t|
      t.references :user,      null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :role,   null: false, default: "sale"    # bod / admin / sale / receptionist / teacher
      t.string :status, null: false, default: "active"  # active / suspended

      t.timestamps
    end

    add_index :memberships, [:user_id, :workspace_id], unique: true
    add_index :memberships, [:workspace_id, :role]
  end
end
