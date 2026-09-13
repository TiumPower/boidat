class AddQrTokenToGuardians < ActiveRecord::Migration[7.2]
  def up
    add_column :guardians, :qr_token, :string
    add_column :guardians, :qr_issued_at, :datetime
    add_column :guardians, :qr_revoked_at, :datetime
    add_index  :guardians, :qr_token, unique: true

    # Cấp mã cho người đang có. Chủ hộ kế thừa đúng mã của hộ để các link đã
    # phát ra không chết; người đưa đón nhận mã mới của riêng mình.
    execute <<~SQL
      UPDATE guardians g
         SET qr_token = h.qr_token, qr_issued_at = COALESCE(h.qr_issued_at, NOW())
        FROM households h
       WHERE g.household_id = h.id
         AND g.role = 'owner'
         AND g.qr_token IS NULL
         AND NOT EXISTS (
           SELECT 1 FROM guardians g2
            WHERE g2.household_id = g.household_id AND g2.role = 'owner' AND g2.id < g.id
         )
    SQL

    Guardian.reset_column_information
    Guardian.unscoped.where(qr_token: nil).find_each do |g|
      g.update_columns(qr_token: SecureRandom.urlsafe_base64(18), qr_issued_at: Time.current)
    end

    change_column_null :guardians, :qr_token, false
  end

  def down
    remove_column :guardians, :qr_token
    remove_column :guardians, :qr_issued_at
    remove_column :guardians, :qr_revoked_at
  end
end
