class AddCurrentDeploymentIdToProjects < ActiveRecord::Migration[7.2]
  def change
    add_reference :projects, :current_deployment, foreign_key: { to_table: :deployments }, null: true
  end
end
