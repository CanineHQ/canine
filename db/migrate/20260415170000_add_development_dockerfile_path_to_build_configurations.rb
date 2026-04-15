class AddDevelopmentDockerfilePathToBuildConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :build_configurations, :development_dockerfile_path, :string
  end
end
