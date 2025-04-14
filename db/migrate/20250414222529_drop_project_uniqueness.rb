class DropProjectUniqueness < ActiveRecord::Migration[7.2]
  def change
    remove_index :projects, :name
  end
end
