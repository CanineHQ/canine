# == Schema Information
#
# Table name: oidc_configurations
#
#  id                     :bigint           not null, primary key
#  authorization_endpoint :string
#  client_secret          :string           not null
#  issuer                 :string           not null
#  jwks_uri               :string
#  scopes                 :string           default("openid email profile")
#  token_endpoint         :string
#  userinfo_endpoint      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  client_id              :string           not null
#
FactoryBot.define do
  factory :oidc_configuration do
    issuer { "MyString" }
    client_id { "MyString" }
    client_secret { "MyString" }
    authorization_endpoint { "MyString" }
    token_endpoint { "MyString" }
    userinfo_endpoint { "MyString" }
    jwks_uri { "MyString" }
    scopes { "MyString" }
  end
end
