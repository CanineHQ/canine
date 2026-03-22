class AddAllowMCPToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :allow_mcp, :boolean, default: true, null: false
  end
end
