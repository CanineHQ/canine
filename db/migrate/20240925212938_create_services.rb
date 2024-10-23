class CreateServices < ActiveRecord::Migration[7.2]
  def change
    create_table :services do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :service_type, null: false
      t.string :command
      t.string :name, null: false
      t.integer :replicas, default: 1
      t.string :healthcheck_url
      t.boolean :allow_public_networking, default: false
      t.integer :status, default: 0
      t.datetime :last_health_checked_at
      t.integer :container_port, default: 3000

      t.timestamps
    end
  end
end
