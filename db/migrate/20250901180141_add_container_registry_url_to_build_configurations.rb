class AddContainerRegistryUrlToBuildConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :build_configurations, :image_repository, :string, null: false
  end
end
