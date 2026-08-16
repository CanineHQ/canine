class AddHealthMonitoringToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :health_monitoring, :boolean, default: false, null: false
  end
end
