class CreateDeploymentConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :deployment_configurations do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :deployment_method, null: false, default: 0

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        Project.find_each do |project|
          DeploymentConfiguration.create!(project: project, deployment_method: :legacy)
        end
      end
    end
  end
end
