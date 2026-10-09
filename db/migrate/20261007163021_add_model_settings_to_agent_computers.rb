class AddModelSettingsToAgentComputers < ActiveRecord::Migration[7.2]
  def change
    # Machine-level model defaults; runs on this computer inherit them, and a task can still override in its spec.
    # Null means "inherit": planning falls back to the global default, browse and coding to the planning model.
    add_column :agent_computers, :planning_model, :string
    add_column :agent_computers, :browse_model, :string
    add_column :agent_computers, :coding_model, :string
    add_column :agent_computers, :coding_agent, :string
  end
end
