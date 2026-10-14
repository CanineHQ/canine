class CreateErrorTracking < ActiveRecord::Migration[7.2]
  def change
    create_table :error_tracking_configurations do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :public_key, null: false
      t.timestamps
    end
    add_index :error_tracking_configurations, :public_key, unique: true

    create_table :error_tracking_issues do |t|
      t.references :error_tracking_configuration, null: false, foreign_key: { on_delete: :cascade }, index: false
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
    add_index :error_tracking_issues, %i[error_tracking_configuration_id fingerprint], unique: true
    add_index :error_tracking_issues, %i[error_tracking_configuration_id status last_seen_at]

    create_table :error_tracking_events do |t|
      t.references :issue, null: false, foreign_key: { to_table: :error_tracking_issues, on_delete: :cascade }, index: false
      t.string :event_id, null: false
      t.string :environment
      t.string :release
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :error_tracking_events, %i[issue_id occurred_at]
    add_index :error_tracking_events, :occurred_at
  end
end
