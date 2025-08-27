class CreateStackManagers < ActiveRecord::Migration[7.2]
  def change
    create_table :stack_managers do |t|
      t.integer :stack_manager_type, null: false, default: 0
      t.string :provider_url, null: false
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end
  end
end
