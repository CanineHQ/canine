class RemoveDockerCommandFromProjects < ActiveRecord::Migration[7.2]
  def change
    remove_column :projects, :docker_command, :string
  end
end
