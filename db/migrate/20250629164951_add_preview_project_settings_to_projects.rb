class AddPreviewProjectSettingsToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :project_fork_cluster_id, :bigint
    add_foreign_key :projects, :clusters, column: :project_fork_cluster_id
    add_column :projects, :project_fork_status, :integer, default: 0
  end
end
