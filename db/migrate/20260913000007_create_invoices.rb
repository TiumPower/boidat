# Hoá đơn thuê bao nền tảng (super admin thu tiền của trung tâm).
# KHÁC với Order — đơn hàng khoá học mà trung tâm thu của phụ huynh.
class CreateInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :invoices do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string   :plan,   null: false
      t.integer  :amount, null: false, default: 0
      t.string   :status, null: false, default: "pending" # pending / paid / failed / cancelled
      t.date     :period_start, null: false
      t.date     :period_end,   null: false
      t.bigint   :payos_order_code
      t.string   :checkout_url
      t.datetime :paid_at
      t.jsonb    :gateway_response, null: false, default: {}
      t.timestamps
    end
    add_index :invoices, :payos_order_code, unique: true, where: "payos_order_code IS NOT NULL"
    add_index :invoices, [:workspace_id, :status]
  end
end
