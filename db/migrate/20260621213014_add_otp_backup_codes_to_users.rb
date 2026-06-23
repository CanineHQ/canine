class AddOtpBackupCodesToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :otp_backup_codes, :string, array: true
  end
end
