# Nhận xét sau buổi học (FR-303/406), chấm công tự động (FR-210/301) và vé lẻ
# dùng một lần (FR-214, OQ-13).
class CreateTeachingRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :session_feedbacks do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :lesson,    null: false, foreign_key: true
      t.references :student,   null: false, foreign_key: true
      t.references :teacher,   null: false, foreign_key: true
      t.string :tag                                     # progress / needs_work / afraid
      t.text   :body
      t.datetime :sent_at                               # gửi cho phụ huynh lúc nào
      t.datetime :read_at
      t.timestamps
    end
    add_index :session_feedbacks, [:lesson_id, :student_id], unique: true
    add_index :session_feedbacks, [:workspace_id, :student_id, :created_at],
              name: "index_feedbacks_on_student_time"

    create_table :payroll_periods do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: true,  foreign_key: true
      t.references :locked_by, null: true,  foreign_key: { to_table: :users }
      t.date     :starts_on, null: false
      t.date     :ends_on,   null: false
      t.datetime :locked_at
      t.decimal  :total_credits, precision: 8, scale: 2, null: false, default: 0
      t.integer  :total_amount, null: false, default: 0
      t.timestamps
    end
    add_index :payroll_periods, [:workspace_id, :pool_id, :starts_on],
              name: "index_payroll_on_pool_start"

    # Một dòng công cho mỗi (giáo viên × buổi). Tính từ dữ liệu điểm danh, không
    # ai nhập tay — màn hình chấm công là màn hình chỉ đọc (FR-210).
    create_table :timesheet_entries do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :teacher,   null: false, foreign_key: true
      t.references :lesson,    null: false, foreign_key: true
      t.references :payroll_period, null: true, foreign_key: true
      t.integer :headcount,   null: false, default: 0   # sĩ số dùng để tính công
      t.string  :basis,       null: false, default: "registered" # registered / present (OQ-06)
      t.decimal :credits, precision: 5, scale: 2, null: false, default: 0
      t.integer :rate,   null: false, default: 0        # đơn giá theo level
      t.integer :amount, null: false, default: 0
      t.string  :status, null: false, default: "pending" # pending / locked
      t.timestamps
    end
    add_index :timesheet_entries, [:lesson_id, :teacher_id], unique: true
    add_index :timesheet_entries, [:workspace_id, :teacher_id, :created_at],
              name: "index_timesheets_on_teacher_time"

    # Vé lẻ dùng một lần cho khách vãng lai. Cố tình KHÔNG đăng ký khuôn mặt —
    # xin đồng ý dữ liệu sinh trắc học cho một lượt bơi là quá nặng (OQ-13).
    create_table :day_pass_tickets do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :order,     null: true,  foreign_key: true
      t.references :issued_by, null: true,  foreign_key: { to_table: :users }
      t.string   :code, null: false
      t.string   :guest_name
      t.string   :guest_phone
      t.integer  :quantity, null: false, default: 1
      t.date     :valid_on, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :day_pass_tickets, :code, unique: true
    add_index :day_pass_tickets, [:workspace_id, :pool_id, :valid_on]
  end
end
