class CreateEmailPreferences < ActiveRecord::Migration[7.2]
  def change
    create_table :email_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :service_health, default: true, null: false

      t.timestamps
    end
  end
end
