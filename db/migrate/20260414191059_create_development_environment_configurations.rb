class CreateDevelopmentEnvironmentConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :development_environment_configurations do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.string :dockerfile_path, null: false
      t.string :application_path, null: false
      t.string :anthropic_api_key
      t.string :branch_name, null: false
      t.string :ssh_username, default: "developer"
      t.string :ssh_password
      t.integer :ssh_port, default: 2222
      t.boolean :enabled, default: true

      t.timestamps
    end
  end
end
