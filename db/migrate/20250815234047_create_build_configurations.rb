class CreateBuildConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :build_configurations do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :driver, null: false
      t.references :build_cloud, null: true, foreign_key: true

      t.timestamps
    end
  end
end
