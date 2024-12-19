class AddIndexToClustersAndName < ActiveRecord::Migration[7.2]
  def change
    remove_index :clusters, :account_id
    add_index :clusters, [ :account_id, :name ], unique: true
  end
end
