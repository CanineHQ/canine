class CreateShellTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :shell_tokens do |t|
      t.string :token, null: false
      t.references :user, null: false, foreign_key: true
      t.references :cluster, null: false, foreign_key: true
      t.string :pod_name, null: false
      t.string :namespace, null: false
      t.string :container
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :shell_tokens, :token, unique: true
  end
end
