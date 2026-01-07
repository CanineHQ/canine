class AddIndexToNameForProjectsAndAddOns < ActiveRecord::Migration[7.2]
  def change
    add_index :projects, :name
    add_index :add_ons, :name
  end
end
