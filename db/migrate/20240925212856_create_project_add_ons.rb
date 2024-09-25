class CreateProjectAddOns < ActiveRecord::Migration[7.2]
  def change
    create_table :project_add_ons do |t|
      t.references :project, null: false, foreign_key: true
      t.references :add_on, null: false, foreign_key: true

      t.timestamps
    end
  end
end
