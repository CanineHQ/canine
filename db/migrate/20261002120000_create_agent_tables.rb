# The scheduled agent loop: provider keys, tasks, their sessions, and each session's messages, timeline (activities
# and the actions under them) and feed posts. (See app/services/agent_loop and app/jobs/agent_sessions.)
class CreateAgentTables < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_provider_keys do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false, default: "openrouter"
      t.string :name
      t.text :api_key, null: false
      t.datetime :last_used_at
      t.timestamps
    end

    create_table :agent_tasks do |t|
      t.references :agent_computer, null: false, foreign_key: true
      t.string :name, null: false
      t.text :instruction, null: false
      t.jsonb :spec, null: false, default: {}
      t.string :schedule, null: false
      t.string :model, null: false
      t.boolean :enabled, null: false, default: false
      t.datetime :next_run_at
      t.timestamps
      t.index %i[enabled next_run_at]
    end

    create_table :agent_sessions do |t|
      t.references :agent_computer, null: false, foreign_key: true
      t.references :agent_task, null: true, foreign_key: true
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
      t.timestamps
      t.index %i[agent_task_id status]
    end

    create_table :agent_session_messages do |t|
      t.references :agent_session, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :role, null: false
      t.jsonb :content
      t.jsonb :tool_calls
      t.string :tool_call_id
      t.timestamps
      t.index %i[agent_session_id position], unique: true
    end

    create_table :agent_session_activities do |t|
      t.references :agent_session, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :intent
      t.string :title, null: false
      t.text :description
      t.text :outcome
      t.integer :first_message_position
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :tidied_at
      t.timestamps
    end

    create_table :agent_session_actions do |t|
      t.references :agent_session, null: false, foreign_key: true
      t.references :agent_session_activity, null: false, foreign_key: true
      t.string :tool, null: false
      t.string :tool_call_id
      t.jsonb :arguments, null: false, default: {}
      t.jsonb :result
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.integer :duration_ms
      t.timestamps
    end

    create_table :agent_posts do |t|
      t.references :agent_computer, null: false, foreign_key: true
      t.references :agent_session, null: false, foreign_key: true
      t.references :agent_session_activity, null: true, foreign_key: { on_delete: :nullify } # tidying merges activities away
      t.references :agent_session_action, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.text :text, null: false
      t.datetime :posted_at, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index %i[agent_computer_id posted_at]
    end
  end
end
