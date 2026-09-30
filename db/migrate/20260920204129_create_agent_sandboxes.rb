class CreateAgentSandboxes < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_sandboxes do |t|
      t.string :name, null: false
      t.integer :status, null: false, default: 0
      t.references :account_user, null: false, foreign_key: true
      t.references :cluster, null: false, foreign_key: true

      t.timestamps
    end
  end
end
