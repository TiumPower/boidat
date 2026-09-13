# Lịch dạy: đăng ký khung giờ của giáo viên (FR-304) → lớp (FR-204) → buổi học
# cụ thể (hạt nhân của bảng master data, chấm công và điểm danh).
class CreateScheduling < ActiveRecord::Migration[7.2]
  def change
    # Giáo viên đăng ký khung giờ sẵn sàng dạy trong tháng tới. Đây là đầu vào
    # bắt buộc của bộ xếp lịch tự động (FR-205).
    create_table :teacher_availabilities do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :teacher,   null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.date    :month,   null: false          # luôn là ngày 1 của tháng
      t.integer :weekday, null: false          # 0 = Chủ nhật
      t.integer :hour,    null: false          # giờ bắt đầu tiết, 0..23
      t.datetime :submitted_at                 # đã gửi cho admin hay còn nháp
      t.timestamps
    end
    add_index :teacher_availabilities, [:teacher_id, :month, :weekday, :hour, :pool_id],
              unique: true, name: "index_availability_unique_slot"
    add_index :teacher_availabilities, [:workspace_id, :pool_id, :month]

    # Một lớp = một nhóm học viên học cố định với một giáo viên, một khung giờ.
    # Lớp chưa kết thúc khoá thì bộ xếp lịch tự động KHÔNG được xáo lại (OQ-08).
    create_table :swim_classes do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :teacher,   null: false, foreign_key: true
      t.references :course,    null: true,  foreign_key: true
      t.string  :code                                  # #4821 — hiển thị trên bảng lịch
      t.integer :class_type, null: false, default: 1   # 1..4 học viên
      t.integer :start_hour, null: false
      t.jsonb   :weekdays, null: false, default: []    # [1,3] = T2 & T4
      t.date    :start_date, null: false
      t.date    :end_date
      t.string  :status, null: false, default: "running" # running / finished / cancelled
      # class = lớp của trung tâm · rental = giờ giáo viên ngoài thuê hồ (FR-225)
      t.string  :kind, null: false, default: "class"
      t.timestamps
    end
    add_index :swim_classes, [:workspace_id, :pool_id, :status]
    add_index :swim_classes, :code, unique: true, where: "code IS NOT NULL"

    # Một buổi học cụ thể = một tiết 60 phút của một lớp vào một ngày.
    create_table :lessons do |t|
      t.references :workspace,  null: false, foreign_key: true
      t.references :pool,       null: false, foreign_key: true
      t.references :teacher,    null: false, foreign_key: true
      t.references :swim_class, null: false, foreign_key: true
      t.date     :date,        null: false
      t.integer  :start_hour,  null: false
      t.integer  :session_index                          # buổi thứ mấy của khoá
      t.string   :status, null: false, default: "scheduled" # scheduled / done / cancelled
      t.string   :cancel_reason
      t.text     :content_override                       # giáo viên sửa giáo án cho riêng buổi này
      t.boolean  :exam, null: false, default: false
      t.datetime :completed_at
      t.timestamps
    end
    add_index :lessons, [:workspace_id, :pool_id, :date]
    add_index :lessons, [:teacher_id, :date, :start_hour]
    add_index :lessons, [:swim_class_id, :session_index]

    # Đăng ký học: học viên × lớp × gói. SessionBalance nằm luôn ở đây cho gọn.
    create_table :enrollments do |t|
      t.references :workspace,  null: false, foreign_key: true
      t.references :pool,       null: false, foreign_key: true
      t.references :student,    null: false, foreign_key: true
      t.references :swim_class, null: false, foreign_key: true
      t.references :package,    null: true,  foreign_key: true
      t.integer  :sessions_total, null: false, default: 0
      t.integer  :sessions_used,  null: false, default: 0
      t.integer  :bonus_sessions, null: false, default: 0   # từ khuyến mãi
      t.date     :starts_on
      t.date     :expires_on                                # hạn 1 năm (BR-11)
      t.string   :status, null: false, default: "active"    # active / finished / expired / cancelled
      t.string   :customer_type, null: false, default: "new" # new / returning (FR-220)
      t.datetime :exam_eligible_at
      t.string   :exam_result                               # passed / failed / retake
      t.date     :exam_date
      t.timestamps
    end
    add_index :enrollments, [:workspace_id, :status]
    add_index :enrollments, [:student_id, :swim_class_id], unique: true

    # Điểm danh: một dòng cho mỗi học viên trong mỗi buổi.
    create_table :attendances do |t|
      t.references :workspace,  null: false, foreign_key: true
      t.references :pool,       null: false, foreign_key: true
      t.references :lesson,     null: false, foreign_key: true
      t.references :student,    null: false, foreign_key: true
      t.references :enrollment, null: true,  foreign_key: true
      t.references :actor,      null: true,  foreign_key: { to_table: :users }
      # present = có mặt (trừ buổi) · absent = vắng (KHÔNG trừ buổi, BR-12)
      # rejected = quét ra nhưng không cho điểm danh (sai hồ / không có lịch)
      t.string   :status, null: false, default: "present"
      # face = quét khuôn mặt · qr = vé lẻ QR một lần · manual = admin sửa tay (FR-234)
      t.string   :method, null: false, default: "manual"
      t.float    :face_score
      t.boolean  :deducted, null: false, default: false
      t.datetime :checked_in_at
      t.string   :note
      t.timestamps
    end
    add_index :attendances, [:lesson_id, :student_id], unique: true
    add_index :attendances, [:workspace_id, :pool_id, :checked_in_at]

    # Đơn hàng của trung tâm (FR-220) — khác Invoice (thuê bao nền tảng).
    create_table :orders do |t|
      t.references :workspace,  null: false, foreign_key: true
      t.references :pool,       null: false, foreign_key: true
      t.references :household,  null: true,  foreign_key: true
      t.references :student,    null: true,  foreign_key: true
      t.references :enrollment, null: true,  foreign_key: true
      t.references :package,    null: true,  foreign_key: true
      t.references :sale,       null: true,  foreign_key: { to_table: :users }
      t.string   :code, null: false
      t.integer  :amount,   null: false, default: 0
      t.integer  :discount, null: false, default: 0
      t.string   :status, null: false, default: "unpaid" # unpaid / paid / cancelled / refunded
      # course = khoá học · renewal = tái ký · day_pass = vé lẻ · rental = thuê hồ (OQ-26)
      t.string   :kind, null: false, default: "course"
      t.string   :customer_type, null: false, default: "new"
      t.bigint   :payos_order_code
      t.string   :checkout_url
      t.datetime :paid_at
      t.jsonb    :gateway_response, null: false, default: {}
      t.text     :note
      t.timestamps
    end
    add_index :orders, :code, unique: true
    add_index :orders, :payos_order_code, unique: true, where: "payos_order_code IS NOT NULL"
    add_index :orders, [:workspace_id, :pool_id, :status]

    create_table :payments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :order,     null: false, foreign_key: true
      t.references :recorded_by, null: true, foreign_key: { to_table: :users }
      t.integer  :amount, null: false, default: 0
      t.string   :method, null: false, default: "payos" # payos / cash / transfer
      t.datetime :paid_at, null: false
      t.string   :reference
      t.timestamps
    end
    add_index :payments, [:workspace_id, :paid_at]
  end
end
