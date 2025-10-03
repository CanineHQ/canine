class RemoveUniquenessFromExternalIdOnProviders < ActiveRecord::Migration[7.2]
  def change
    remove_index :providers, :external_id
  end
end
