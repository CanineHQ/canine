class RemoveBillingFromAccounts < ActiveRecord::Migration[7.2]
  def change
    remove_index :accounts, :stripe_customer_id, unique: true
    remove_index :accounts, :stripe_subscription_id, unique: true

    remove_column :accounts, :stripe_customer_id, :string
    remove_column :accounts, :stripe_subscription_id, :string
    remove_column :accounts, :plan, :integer, default: 0, null: false
    remove_column :accounts, :subscription_status, :integer
  end
end
