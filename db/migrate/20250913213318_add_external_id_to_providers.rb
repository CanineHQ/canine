class AddExternalIdToProviders < ActiveRecord::Migration[7.2]
  def change
    add_column :providers, :external_id, :string, null: true
    add_index :providers, :external_id, unique: true
  end
end
