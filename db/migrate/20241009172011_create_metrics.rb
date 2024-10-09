class CreateMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :metrics do |t|
      t.integer :metric_type, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.jsonb :tags, null: false, default: [], array: true
      t.references :cluster, null: false
      t.timestamps
    end
  end
end
