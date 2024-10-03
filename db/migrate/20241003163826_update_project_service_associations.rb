class UpdateProjectServiceAssociations < ActiveRecord::Migration[7.2]
  def change
    rename_column :domains, :project_service_id, :service_id
  end
end
