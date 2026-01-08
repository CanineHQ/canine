class CreateFavorites < ActiveRecord::Migration[7.2]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :favoriteable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :favorites,
              [ :user_id, :account_id, :favoriteable_type, :favoriteable_id ],
              unique: true,
              name: "index_favorites_unique"
  end
end
