class AddLastUsedAtToProviders < ActiveRecord::Migration[7.2]
  def change
    add_column :providers, :last_used_at, :datetime
  end
end
