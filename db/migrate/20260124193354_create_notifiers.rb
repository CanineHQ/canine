class CreateNotifiers < ActiveRecord::Migration[7.2]
  def change
    create_table :notifiers do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :provider_type, null: false, default: 0
      t.string :webhook_url, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
  end
end
