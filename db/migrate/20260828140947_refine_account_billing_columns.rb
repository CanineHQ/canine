class RefineAccountBillingColumns < ActiveRecord::Migration[7.2]
  def up
    remove_column :accounts, :trial_ends_at
    remove_column :accounts, :subscription_status
    add_column :accounts, :subscription_status, :integer
  end

  def down
    remove_column :accounts, :subscription_status
    add_column :accounts, :subscription_status, :string
    add_column :accounts, :trial_ends_at, :datetime
  end
end
