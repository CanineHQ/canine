class CreateDevelopmentEnvironmentConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :development_environment_configurations do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.references :git_provider, foreign_key: { to_table: :providers }, index: { name: "index_dev_env_configs_on_git_provider_id" }
      t.string :dockerfile_path, null: false
      t.string :workspace_mount_path, null: false
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end
  end
end
