class CreateErrorTracking < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :error_tracking_key, :string
    add_index :projects, :error_tracking_key, unique: true

    create_table :error_issues do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.string :fingerprint, null: false
      t.string :title, null: false
      t.string :culprit
      t.string :level, null: false, default: "error"
      t.string :platform
      t.integer :status, null: false, default: 0
      t.integer :times_seen, null: false, default: 0
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :error_issues, %i[project_id fingerprint], unique: true
    add_index :error_issues, %i[project_id status last_seen_at]

    create_table :error_events do |t|
      t.references :error_issue, null: false, foreign_key: { on_delete: :cascade }
      t.string :event_id, null: false
      t.string :environment
      t.string :release
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :error_events, %i[error_issue_id occurred_at]
    add_index :error_events, :occurred_at
  end
end
