class RenameServicesTable < ActiveRecord::Migration[7.2]
  def change
    rename_table :services, :providers
    rename_table :project_services, :services
  end
end
