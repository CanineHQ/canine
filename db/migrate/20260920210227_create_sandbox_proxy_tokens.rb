class CreateSandboxProxyTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :sandbox_proxy_tokens do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :pod_name, null: false
      t.string :namespace, null: false
      t.datetime :expires_at, null: false
      t.datetime :connected_at
      t.references :agent_sandbox, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
