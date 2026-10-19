class AddClusterRegistryToBuildConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :build_configurations, :cluster_registry, :boolean, default: false, null: false
    change_column_null :build_configurations, :provider_id, true
  end
end
