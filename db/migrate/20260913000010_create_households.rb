# Hộ gia đình (FR-206) — đơn vị đăng nhập của cổng phụ huynh. Một mã QR dùng
# chung cho cả nhà, thu hồi và cấp lại được (OQ-02).
class CreateHouseholds < ActiveRecord::Migration[7.2]
  def change
    create_table :households do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string   :name,     null: false            # "Gia đình Trần Văn Đạt"
      t.string   :kind,     null: false, default: "family" # family / individual (người lớn tự học)
      t.string   :qr_token, null: false
      t.datetime :qr_issued_at
      t.datetime :qr_revoked_at
      t.timestamps
    end
    add_index :households, :qr_token, unique: true
    add_index :households, [:workspace_id, :name]

    # Người giám hộ / người đưa đón. role quyết định có xem được thanh toán không (OQ-03).
    create_table :guardians do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.string :name,  null: false
      t.string :phone
      t.string :email
      t.string :relation                            # bố / mẹ / ông bà / người giúp việc
      t.string :role,  null: false, default: "owner" # owner (chủ hộ) / pickup (người đưa đón)
      t.boolean :is_student, null: false, default: false # người lớn tự học: vừa là HV vừa là chủ hộ
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :guardians, [:workspace_id, :phone]

    # Học viên — khoá cứng theo hồ đã đăng ký (OQ-23).
    create_table :students do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :guardian,  null: true,  foreign_key: true # với người lớn tự học
      t.string  :name, null: false
      t.date    :birthdate
      t.string  :gender
      t.text    :health_notes                        # "hen suyễn nhẹ" — hiện cho giáo viên
      t.string  :source                              # giới thiệu / facebook / google / vãng lai (OQ-17)
      # center = học viên của trung tâm; renter = học viên của giáo viên thuê hồ (FR-225)
      t.string  :kind,   null: false, default: "center"
      t.string  :status, null: false, default: "active" # active / graduated / inactive
      t.datetime :exam_eligible_at                   # cờ dính, không rớt khỏi danh sách thi (OQ-07)
      t.timestamps
    end
    add_index :students, [:workspace_id, :pool_id]
    add_index :students, [:workspace_id, :name]

    # Hồ sơ khuôn mặt. Vector nằm ở face_service; ở đây chỉ giữ metadata + ảnh.
    create_table :face_profiles do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :student,   null: false, foreign_key: true
      t.string   :external_ref                       # id trong face_service
      t.string   :embedding_version                  # buffalo_l / …
      t.float    :quality
      t.integer  :samples_count, null: false, default: 0
      t.datetime :captured_at
      t.boolean  :recapture_flag, null: false, default: false # ảnh cũ, cần chụp lại (OQ-01.3)
      t.integer  :fail_count,  null: false, default: 0
      t.integer  :scan_count,  null: false, default: 0
      t.datetime :deleted_at                         # quyền xoá dữ liệu sinh trắc (NĐ 13/2023)
      t.timestamps
    end
    add_index :face_profiles, [:workspace_id, :student_id], unique: true

    # Bằng chứng đồng ý xử lý dữ liệu sinh trắc học (FR-402).
    create_table :biometric_consents do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :student,   null: false, foreign_key: true
      t.references :guardian,  null: true,  foreign_key: true
      t.string   :terms_version, null: false
      t.string   :ip
      t.string   :user_agent
      t.datetime :consented_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
  end
end
