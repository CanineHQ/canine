class CreateSAMLConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :saml_configurations do |t|
      t.string :idp_entity_id, null: false
      t.string :idp_sso_service_url, null: false
      t.text :idp_cert, null: false
      t.string :idp_slo_service_url
      t.string :name_identifier_format, default: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      t.string :uid_attribute, default: "email"
      t.string :email_attribute, default: "email"
      t.string :name_attribute, default: "name"
      t.string :groups_attribute
      t.string :sp_entity_id
      t.boolean :authn_requests_signed, default: false
      t.boolean :want_assertions_signed, default: true

      t.timestamps
    end
  end
end
