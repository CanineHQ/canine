class CreateEnvironmentVariables < ActiveRecord::Migration[7.2]
  def change
     create_table :environment_variables do |t|
      t.string :name, null: false
      t.text :value
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
    add_index :environment_variables, [ :project_id, :name ], unique: true
  end
end
