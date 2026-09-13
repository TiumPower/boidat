# Một Workspace = một trung tâm dạy bơi (ví dụ BƠI ĐẠT). Bên trong có nhiều hồ
# bơi (Pool). PWA của phụ huynh chạy trên subdomain riêng của workspace.
class CreateWorkspaces < ActiveRecord::Migration[7.2]
  def change
    create_table :workspaces do |t|
      t.string   :name,           null: false
      t.string   :slug,           null: false
      t.string   :subdomain,      null: false
      t.string   :custom_domain
      t.datetime :domain_verified_at
      t.string   :status,         null: false, default: "trial" # trial / active / past_due / suspended
      t.string   :plan,           null: false, default: "starter"
      t.string   :locale_default, null: false, default: "vi"

      t.datetime :paid_until
      t.boolean  :auto_renew, null: false, default: false

      t.jsonb    :theme,    null: false, default: {}
      t.jsonb    :branding, null: false, default: {}
      t.jsonb    :settings, null: false, default: {} # gồm cả cấu hình nghiệp vụ (WorkspaceSetting)

      t.timestamps
    end

    add_index :workspaces, :slug,          unique: true
    add_index :workspaces, :subdomain,     unique: true
    add_index :workspaces, :custom_domain, unique: true, where: "custom_domain IS NOT NULL"
    add_index :workspaces, :status
  end
end
