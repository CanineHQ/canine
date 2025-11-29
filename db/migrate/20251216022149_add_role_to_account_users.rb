class AddRoleToAccountUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :account_users, :role, :integer, default: 2, null: false
  end
end
