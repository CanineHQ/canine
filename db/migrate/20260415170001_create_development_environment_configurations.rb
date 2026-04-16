class CreateDevelopmentEnvironmentConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :development_environment_configurations do |t|
      t.references :cluster, foreign_key: true
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.references :llm_provider, foreign_key: { to_table: :providers }
      t.references :git_provider, foreign_key: { to_table: :providers }
      t.string :dockerfile_path
      t.string :workspace_mount_path
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end
  end
end
