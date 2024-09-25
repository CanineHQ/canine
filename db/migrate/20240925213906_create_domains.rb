class CreateDomains < ActiveRecord::Migration[7.2]
   def change
    create_table :domains do |t|
      t.references :project_service, null: false, foreign_key: true
      t.string :domain_name, null: false

      t.timestamps
    end
  end
end
