class AddRegistryUrlToProviders < ActiveRecord::Migration[7.2]
  def change
    add_column :providers, :registry_url, :string
  end
end
