class ChangeCurrentDeploymentForeignKeyOnProjects < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :projects, column: :current_deployment_id
    add_foreign_key :projects, :deployments, column: :current_deployment_id, on_delete: :nullify
  end
end
