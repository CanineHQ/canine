class RenameAgentSandboxesToAgentComputers < ActiveRecord::Migration[7.2]
  def up
    # Leftover from an earlier proxy design; nothing creates these anymore
    drop_table :sandbox_proxy_tokens
    rename_table :agent_sandboxes, :agent_computers
  end

  def down
    rename_table :agent_computers, :agent_sandboxes
    create_table :sandbox_proxy_tokens do |t|
      t.references :agent_sandbox, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :pod_name, null: false
      t.string :namespace, null: false
      t.datetime :expires_at, null: false
      t.datetime :connected_at
      t.timestamps
    end
    add_index :sandbox_proxy_tokens, :token, unique: true
  end
end
