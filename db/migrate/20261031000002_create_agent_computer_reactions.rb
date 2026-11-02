class CreateAgentComputerReactions < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_computer_reactions do |t|
      t.references :post, null: false, foreign_key: { to_table: :agent_computer_posts, on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.string :tag, null: false
      t.timestamps
    end
    add_index :agent_computer_reactions, %i[post_id user_id], unique: true # one tag per person per post, like a reaction
  end
end
