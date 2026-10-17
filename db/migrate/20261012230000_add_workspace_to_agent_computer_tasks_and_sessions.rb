class AddWorkspaceToAgentComputerTasksAndSessions < ActiveRecord::Migration[7.2]
  def change
    # The Hyprland workspace a run's windows open on: the task's, or (blank) one the computer picks when the run starts
    add_column :agent_computer_tasks, :workspace, :integer
    add_column :agent_computer_sessions, :workspace, :integer
  end
end
