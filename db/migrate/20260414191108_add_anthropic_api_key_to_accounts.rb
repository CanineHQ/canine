class AddAnthropicApiKeyToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :anthropic_api_key, :string
  end
end
