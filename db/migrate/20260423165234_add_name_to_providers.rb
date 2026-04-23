class AddNameToProviders < ActiveRecord::Migration[7.2]
  def change
    add_column :providers, :name, :string
  end
end
