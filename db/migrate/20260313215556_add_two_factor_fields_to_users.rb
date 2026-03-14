class AddTwoFactorFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :otp_secret, :text
    add_column :users, :otp_required_for_login, :boolean, default: false
    add_column :users, :otp_backup_codes, :text
  end
end
