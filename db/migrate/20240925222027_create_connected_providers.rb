class CreateConnectedProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :connected_providers do |t|
      t.references :owner, polymorphic: true, index: true
      t.string :access_token
      t.string :access_token_secret
      t.text :auth
      t.string :provider
      t.string :refresh_token
      t.string :uid
      t.datetime :expires_at
      t.timestamps
    end
  end
end
