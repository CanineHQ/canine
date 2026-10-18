# Agent computers and the scheduled agent loop, compacted from the branch's incremental migrations: a computer (a
# KubeVirt VM), the account's provider keys, and the computer's tasks, their sessions, and each session's messages,
# timeline (activities and the actions under them) and feed posts. The models live under AgentComputer::
# (app/models/agent_computer/), so their tables are agent_computer_*. (See app/services/agent_loop, app/jobs/agent_*.)
class CreateAgentComputerTables < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_computers do |t|
      t.string :name, null: false
      t.integer :status, null: false, default: 0
      t.references :account_user, null: false, foreign_key: true
      t.references :cluster, null: false, foreign_key: true, index: false
      t.timestamps
      t.string :namespace, null: false
      # The desktop login password (lock screen, sudo) and the key Canine uses to finish setting up the VM over SSH
      t.string :password
      t.text :ssh_private_key
      # The bearer token Canine sends the computer-use server in the VM (resources/agent_computer/computer_use/auth.py)
      t.string :computer_use_token
      # Machine-level model defaults; runs inherit them (a task picks its own planning model). Null means "inherit":
      # planning falls back to the global default, browse and coding to the planning model.
      t.string :planning_model
      t.string :browse_model
      t.string :coding_model
      t.string :coding_agent
      t.text :failure # why the last provision, start, stop or destroy failed
      t.integer :provision_stage, null: false, default: 0 # where provisioning is, in AgentComputer::PROVISION_STAGES
      t.index %i[cluster_id name], unique: true
    end

    create_table :agent_provider_keys do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false, default: "openrouter"
      t.string :name
      t.text :api_key, null: false
      t.datetime :last_used_at
      t.timestamps
    end

    create_table :agent_computer_tasks do |t|
      t.references :agent_computer, null: false, foreign_key: true
      t.string :name, null: false
      t.text :instruction, null: false
      t.string :schedule # a cron schedule to recur on, or null for a one-off run
      t.string :model, null: false
      t.boolean :enabled, null: false, default: false
      t.datetime :next_run_at
      # Canine stops a run at whichever limit it reaches first (AgentLoop::Policy)
      t.integer :max_minutes, null: false, default: 45
      t.decimal :max_cost_usd, precision: 10, scale: 2, null: false, default: 2.0
      t.integer :max_turns, null: false, default: 120
      t.string :time_zone # the person's, e.g. "America/New_York": run times are shown and given to the agent in it
      # The Hyprland workspace its runs must use, or null (usual) for any free one; each run records the one it got
      t.integer :pinned_workspace
      t.timestamps
      t.index %i[enabled next_run_at]
    end

    # Each table stores only its direct parent: computer ─< task ─< session ─< activity ─< action, and session ─< post
    create_table :agent_computer_sessions do |t|
      t.references :task, null: false, foreign_key: { to_table: :agent_computer_tasks } # "run now" makes a one-off task
      t.integer :trigger, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :model, null: false
      t.datetime :window_from
      t.datetime :window_to
      t.datetime :started_at
      t.datetime :finished_at
      t.text :summary
      t.text :error
      t.text :notes
      t.integer :notes_through
      t.integer :turns, null: false, default: 0
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.bigint :cached_tokens, null: false, default: 0
      t.decimal :cost_usd, precision: 10, scale: 6, null: false, default: 0
      t.string :provider
      t.integer :workspace # the Hyprland workspace this run's windows open on
      t.timestamps
      t.index %i[task_id status]
    end

    create_table :agent_computer_session_messages do |t|
      t.references :session, null: false, foreign_key: { to_table: :agent_computer_sessions }
      t.integer :position, null: false
      t.string :role, null: false
      t.jsonb :content
      t.jsonb :tool_calls
      t.string :tool_call_id
      t.timestamps
      t.index %i[session_id position], unique: true
    end

    create_table :agent_computer_session_activities do |t|
      t.references :session, null: false, foreign_key: { to_table: :agent_computer_sessions }
      t.integer :position, null: false
      t.string :intent
      t.string :title, null: false
      t.text :description
      t.text :outcome
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :tidied_at
      t.timestamps
    end

    # A tool call. Its session is its activity's: tidying only moves actions between activities of one session
    create_table :agent_computer_session_actions do |t|
      t.references :activity, null: false, foreign_key: { to_table: :agent_computer_session_activities }
      t.string :tool, null: false
      t.string :tool_call_id
      t.jsonb :arguments, null: false, default: {}
      t.jsonb :result
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.integer :duration_ms
      t.timestamps
    end

    create_table :agent_computer_posts do |t|
      t.references :session, null: false, foreign_key: { to_table: :agent_computer_sessions }
      # The step it's about (tidying moves posts along when it merges that step into another), or null for a run that
      # stopped before taking any; and the screenshot shown with it, if any.
      t.references :activity, null: true, foreign_key: { to_table: :agent_computer_session_activities, on_delete: :nullify }
      t.references :screenshot_action, null: true, foreign_key: { to_table: :agent_computer_session_actions, on_delete: :nullify }
      t.string :kind, null: false
      t.text :text, null: false
      t.datetime :posted_at, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index :posted_at # the feed pages by it, across the computer's sessions
    end
  end
end
