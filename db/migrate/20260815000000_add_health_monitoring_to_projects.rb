class AddHealthMonitoringToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :notifiers, :notification_types, :text, array: true, default: %w[build deployment health], null: false
  end
end
