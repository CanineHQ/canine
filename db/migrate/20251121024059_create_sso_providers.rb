class CreateSSOProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :sso_providers do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.references :configuration, polymorphic: true, null: false
      t.string :name, null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end
  end
end
