class AddUniqueIndexToAgentSandboxesName < ActiveRecord::Migration[7.2]
  def change
    remove_index :agent_sandboxes, :cluster_id
    add_index :agent_sandboxes, %i[cluster_id name], unique: true
  end
end
