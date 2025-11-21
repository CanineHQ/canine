class CreateOIDCConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :oidc_configurations do |t|
      t.string :issuer, null: false
      t.string :client_id, null: false
      t.string :client_secret, null: false
      t.string :authorization_endpoint
      t.string :token_endpoint
      t.string :userinfo_endpoint
      t.string :jwks_uri
      t.string :scopes, default: "openid email profile"

      t.timestamps
    end
  end
end
