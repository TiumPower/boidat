# Lối đăng nhập bằng SĐT + OTP đã gỡ khỏi cổng phụ huynh, và nhánh OTP cho nhân
# sự chưa từng được gọi (nhân sự dùng email + mật khẩu, quên thì đi qua Devise
# :recoverable). Không còn chỗ nào phát hay đọc mã nữa.
class DropOtpChallenges < ActiveRecord::Migration[7.2]
  def up
    drop_table :otp_challenges
  end

  def down
    create_table :otp_challenges do |t|
      t.references :workspace, foreign_key: true
      t.string   :identity, null: false
      t.string   :scope,    null: false
      t.string   :purpose
      t.string   :code,     null: false
      t.integer  :attempts, default: 0, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
      t.index [:identity, :scope]
    end
  end
end
