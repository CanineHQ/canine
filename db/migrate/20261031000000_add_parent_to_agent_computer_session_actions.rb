class AddParentToAgentComputerSessionActions < ActiveRecord::Migration[7.2]
  def up
    # A browse's steps belong to it, so the timeline nests them under it
    add_reference :agent_computer_session_actions, :parent, null: true,
                  foreign_key: { to_table: :agent_computer_session_actions, on_delete: :cascade }

    # Existing steps: the browse they followed in their activity (a session does nothing else while a browse runs)
    execute <<~SQL
      UPDATE agent_computer_session_actions step SET parent_id = (
        SELECT browse.id FROM agent_computer_session_actions browse
        WHERE browse.activity_id = step.activity_id AND browse.tool = 'browse' AND browse.created_at <= step.created_at
        ORDER BY browse.created_at DESC LIMIT 1
      )
      WHERE step.tool = 'browse_step'
    SQL
  end

  def down
    remove_reference :agent_computer_session_actions, :parent, foreign_key: { to_table: :agent_computer_session_actions }
  end
end
