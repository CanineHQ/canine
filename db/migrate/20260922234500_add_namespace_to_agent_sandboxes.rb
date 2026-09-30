class AddNamespaceToAgentSandboxes < ActiveRecord::Migration[7.2]
  def up
    add_column :agent_sandboxes, :namespace, :string
    execute "UPDATE agent_sandboxes SET namespace = 'sandbox-' || name"
    change_column_null :agent_sandboxes, :namespace, false
  end

  def down
    remove_column :agent_sandboxes, :namespace
  end
end
