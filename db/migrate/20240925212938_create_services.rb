class CreateServices < ActiveRecord::Migration[7.2]
  def change
    create_table :services do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :service_type, null: false
      t.string :command, null: false
      t.string :name, null: false

      t.timestamps
    end
  end
end
