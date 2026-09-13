# OTP dùng cho: nhân sự quên mật khẩu (scope staff, workspace NULL) và học viên
# người lớn tự học đăng nhập bằng số điện thoại (scope guardian).
class CreateOtpChallenges < ActiveRecord::Migration[7.2]
  def change
    create_table :otp_challenges do |t|
      t.references :workspace, null: true, foreign_key: true
      t.string   :identity, null: false                 # email hoặc số điện thoại
      t.string   :scope,    null: false, default: "staff" # staff / guardian
      t.string   :code,     null: false
      t.string   :purpose,  null: false, default: "login"
      t.integer  :attempts, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :otp_challenges, [:scope, :identity]
    add_index :otp_challenges, [:workspace_id, :identity]
  end
end
