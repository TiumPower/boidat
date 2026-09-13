# Bộ xếp lịch tự động (FR-205) và luồng học bù (FR-211 / FR-404).
class CreateSchedulingAutomation < ActiveRecord::Migration[7.2]
  def change
    # Một lần chạy bộ xếp lịch. Kết quả LUÔN là bản nháp — không bao giờ để
    # thuật toán ghi thẳng vào lịch thật (OQ-08 mục 3).
    create_table :schedule_runs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pool,      null: false, foreign_key: true
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.references :applied_by, null: true, foreign_key: { to_table: :users }
      t.date     :month, null: false
      t.string   :status, null: false, default: "draft" # draft / applied / discarded
      t.jsonb    :proposals, null: false, default: []
      t.jsonb    :metrics,   null: false, default: {}   # độ lệch chuẩn công, số slot lấp được
      t.datetime :applied_at
      t.timestamps
    end
    add_index :schedule_runs, [:workspace_id, :pool_id, :month]

    # Đổi buổi / học bù. Ba nguồn: giáo viên nghỉ (admin duyệt đơn), phụ huynh
    # chủ động xin vắng, hoặc admin dời hộ.
    create_table :makeup_requests do |t|
      t.references :workspace,  null: false, foreign_key: true
      t.references :pool,       null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.references :student,    null: false, foreign_key: true
      t.references :from_lesson, null: true, foreign_key: { to_table: :lessons }
      t.references :to_lesson,   null: true, foreign_key: { to_table: :lessons }
      t.references :leave_request, null: true, foreign_key: true
      t.references :decided_by, null: true, foreign_key: { to_table: :guardians }
      # teacher_leave = thầy nghỉ · guardian_absence = phụ huynh xin vắng
      t.string  :origin, null: false, default: "guardian_absence"
      # follow_teacher = dời buổi giữ nguyên thầy · other_slot = khung khác của thầy
      # other_teacher = giữ khung, đổi thầy
      t.string  :choice
      t.string  :status, null: false, default: "pending" # pending / booked / cancelled
      t.text    :reason
      t.datetime :decided_at
      t.timestamps
    end
    add_index :makeup_requests, [:workspace_id, :status]
    add_index :makeup_requests, [:enrollment_id, :from_lesson_id]
  end
end
