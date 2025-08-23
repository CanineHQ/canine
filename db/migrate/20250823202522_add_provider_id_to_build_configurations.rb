class AddProviderIdToBuildConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_reference :build_configurations, :provider, null: false, foreign_key: true
  end
end
