class AddUniqueIndexToBuildId < ActiveRecord::Migration[7.2]
  def change
    remove_index :deployments, :build_id
    add_index :deployments, :build_id, unique: true
  end
end
