class CreateDevelopmentEnvironmentConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :development_environment_configurations do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.string :dockerfile_path
      t.string :workspace_mount_path
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end
  end
end
