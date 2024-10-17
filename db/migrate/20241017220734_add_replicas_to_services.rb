class AddReplicasToServices < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :replicas, :integer, default: 1
  end
end
