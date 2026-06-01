class AddDefaultToAccountUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :account_users, :default, :boolean, default: false, null: false

    User.find_each do |user|
      user.account_users.order(:created_at).first&.set_default!
    end
  end

  def down
    remove_column :account_users, :default
  end
end
