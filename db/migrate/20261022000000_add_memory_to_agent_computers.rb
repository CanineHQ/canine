class AddMemoryToAgentComputers < ActiveRecord::Migration[7.2]
  def change
    add_column :agent_computers, :memory, :string, default: "8Gi", null: false
  end
end
