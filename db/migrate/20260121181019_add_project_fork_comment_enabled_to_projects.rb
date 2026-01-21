class AddProjectForkCommentEnabledToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :project_fork_comment_enabled, :boolean, default: false, null: false
  end
end
