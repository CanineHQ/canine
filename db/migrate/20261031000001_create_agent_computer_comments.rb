class CreateAgentComputerComments < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_computer_comments do |t|
      t.references :post, null: false, foreign_key: { to_table: :agent_computer_posts, on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      # The follow-up run that acts on it
      t.references :session, foreign_key: { to_table: :agent_computer_sessions, on_delete: :nullify }
      t.timestamps
    end
  end
end
