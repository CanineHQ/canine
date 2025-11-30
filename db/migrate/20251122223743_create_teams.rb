class CreateTeams < ActiveRecord::Migration[7.2]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end

    add_index :teams, :slug, unique: true
    add_index :teams, [ :account_id, :name ], unique: true
  end
end
