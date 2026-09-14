# `app_settings` là kho key/value cấp nền tảng bê từ app khác sang (chỗ đó dùng
# để xoay khoá Zalo ZNS). Ở BƠI ĐẠT không có dòng code nào đọc hay ghi nó, và
# bảng rỗng trên production. Cấu hình của hệ thống này nằm ở
# `workspaces.settings["business"]`, không phải ở đây.
class DropAppSettings < ActiveRecord::Migration[7.2]
  def up
    drop_table :app_settings
  end

  def down
    create_table :app_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
      t.index :key, unique: true
    end
  end
end
