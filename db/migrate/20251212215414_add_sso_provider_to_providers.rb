class AddSSOProviderToProviders < ActiveRecord::Migration[7.2]
  def change
    add_reference :providers, :sso_provider, null: true, foreign_key: true
    add_index :providers, [ :sso_provider_id, :uid ], unique: true, where: "sso_provider_id IS NOT NULL"
  end
end
