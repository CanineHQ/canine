class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.string :uid
      t.string :access_token
      t.string :access_token_secret
      t.string :refresh_token
      t.datetime :expires_at
      t.text :auth

      t.timestamps
    end
  end
end
