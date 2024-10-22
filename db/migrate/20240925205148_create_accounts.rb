class CreateAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :accounts do |t|
      t.references :owner, foreign_key: { to_table: :users }, index: true
      t.string :name, null: false

      t.timestamps
    end
  end
end
