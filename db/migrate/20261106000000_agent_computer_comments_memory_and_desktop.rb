class AgentComputerCommentsMemoryAndDesktop < ActiveRecord::Migration[7.2]
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

    create_table :agent_computer_comments do |t|
      t.references :post, null: false, foreign_key: { to_table: :agent_computer_posts, on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      # The follow-up run that acts on it
      t.references :session, foreign_key: { to_table: :agent_computer_sessions, on_delete: :nullify }
      t.timestamps
    end

    create_table :agent_computer_reactions do |t|
      t.references :post, null: false, foreign_key: { to_table: :agent_computer_posts, on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.string :tag, null: false
      t.timestamps
    end
    add_index :agent_computer_reactions, %i[post_id user_id], unique: true # one tag per person per post, like a reaction

    # A run paused on a question for the person (status waiting_for_person): since when, and how long it has waited in
    # all, which doesn't count against its time limit
    add_column :agent_computer_sessions, :waiting_since, :datetime
    add_column :agent_computer_sessions, :waited_seconds, :integer, default: 0, null: false
    # The browser tab a browse left open when it stopped to ask the person (a code form); the next browse carries on in it
    add_column :agent_computer_sessions, :kept_tab, :string
    # Whether the task got done, as the model said when it finished (done, partly_done, blocked); nil for runs that
    # ended any other way
    add_column :agent_computer_sessions, :outcome, :integer
    # The windows already on a run's workspace when it claimed it (a workspace the person picked): kept open, and
    # listed to the agent. null when the run got a free workspace, cleared for it.
    add_column :agent_computer_sessions, :found_windows, :jsonb

    # What the agent has learned on this computer, across all its runs: one note per line ("- …"), added with the
    # remember tool and shown to every run (AgentLoop::SystemPrompt). Not `memory`, which is the VM's RAM.
    add_column :agent_computers, :long_term_memory, :text
    # The run using the computer's screen (the desktop tool), which only one can do at a time: its workspace is shown
    # and it drives the mouse and keyboard
    add_reference :agent_computers, :screen_session, null: true,
                  foreign_key: { to_table: :agent_computer_sessions, on_delete: :nullify }
    # The model the desktop tool's screen agent uses; null means the browse model
    add_column :agent_computers, :screen_model, :string
  end

  def down
    remove_column :agent_computers, :screen_model
    remove_reference :agent_computers, :screen_session, foreign_key: { to_table: :agent_computer_sessions }
    remove_column :agent_computers, :long_term_memory
    remove_column :agent_computer_sessions, :found_windows
    remove_column :agent_computer_sessions, :outcome
    remove_column :agent_computer_sessions, :kept_tab
    remove_column :agent_computer_sessions, :waited_seconds
    remove_column :agent_computer_sessions, :waiting_since
    drop_table :agent_computer_reactions
    drop_table :agent_computer_comments
    remove_reference :agent_computer_session_actions, :parent, foreign_key: { to_table: :agent_computer_session_actions }
  end
end
