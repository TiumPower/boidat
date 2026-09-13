# Danh mục sản phẩm: khoá học + giáo án từng buổi (FR-212), gói bán và bảng giá
# theo hồ (FR-213), khuyến mãi (OQ-17).
class CreateCatalog < ActiveRecord::Migration[7.2]
  def change
    create_table :courses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :code
      t.text    :description
      t.string  :audience,  null: false, default: "child"   # child / adult
      t.string  :status,    null: false, default: "active"  # active / archived
      t.integer :position,  null: false, default: 0
      # Vòng đời khoá (BR-11 / OQ-25). Để trên từng khoá chứ không hard-code, vì
      # khoá sơ cấp / nâng cao / người lớn nhiều khả năng có số buổi khác nhau (OQ-07).
      t.integer :sessions_count
      t.integer :graduation_at_session
      t.integer :exam_session_index
      t.integer :validity_days
      t.jsonb   :class_types, null: false, default: [1, 2, 3, 4] # loại lớp 1:1 → 1:4
      t.timestamps
    end
    add_index :courses, [:workspace_id, :name]

    # Giáo án mặc định từng buổi — giáo viên sửa được cho riêng buổi của mình.
    create_table :course_sessions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :course,    null: false, foreign_key: true
      t.integer :position, null: false
      t.string  :title,    null: false
      t.text    :content
      t.string  :goal                                  # "Nổi 10 giây", "Bơi 10m"
      t.boolean :exam, null: false, default: false     # buổi thi tốt nghiệp
      t.timestamps
    end
    add_index :course_sessions, [:course_id, :position], unique: true

    create_table :packages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :course,    null: true,  foreign_key: true
      t.string  :name, null: false
      # full_course = trọn khoá · per_session = gói lẻ theo buổi
      # day_pass    = vé lẻ bơi tự do · pool_rental = thuê hồ theo giờ
      t.string  :kind, null: false, default: "full_course"
      t.integer :class_type                    # 1..4 học viên / tiết; nil với vé lẻ và thuê hồ
      t.integer :sessions                      # số buổi bán ra
      t.integer :validity_days                 # nil = lấy theo cấu hình workspace
      t.string  :status, null: false, default: "active"
      t.text    :description
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :packages, [:workspace_id, :kind]

    # Giá theo hồ và theo thời gian: pool_id NULL = áp dụng cho mọi hồ.
    create_table :price_list_items do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :package,   null: false, foreign_key: true
      t.references :pool,      null: true,  foreign_key: true
      t.integer :price, null: false, default: 0
      t.date    :effective_from
      t.date    :effective_to
      t.timestamps
    end
    add_index :price_list_items, [:package_id, :pool_id, :effective_from],
              name: "index_price_items_on_package_pool_from"

    create_table :promotions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: true,  foreign_key: true
      t.string  :name, null: false
      # bonus_sessions = tặng buổi · percent_off = giảm % · sibling = ưu đãi anh chị em
      # gift = quà tặng hiện vật · referral_voucher = voucher giới thiệu
      t.string  :kind, null: false, default: "bonus_sessions"
      t.integer :value, null: false, default: 0
      t.text    :condition_note
      t.integer :stock                                  # với quà hiện vật
      t.string  :status, null: false, default: "active" # active / paused
      t.date    :starts_on
      t.date    :ends_on
      t.timestamps
    end
    add_index :promotions, [:workspace_id, :status]
  end
end
