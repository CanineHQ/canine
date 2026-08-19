class AddBillingToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :stripe_customer_id, :string
    add_column :accounts, :stripe_subscription_id, :string
    add_column :accounts, :plan, :integer, default: 0, null: false
    add_column :accounts, :trial_ends_at, :datetime
    add_column :accounts, :subscription_status, :string

    add_index :accounts, :stripe_customer_id, unique: true
    add_index :accounts, :stripe_subscription_id, unique: true
  end
end
