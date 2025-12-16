# == Schema Information
#
# Table name: oidc_configurations
#
#  id                     :bigint           not null, primary key
#  issuer                 :string           not null
#  client_id              :string           not null
#  client_secret          :string           not null
#  authorization_endpoint :string
#  token_endpoint         :string
#  userinfo_endpoint      :string
#  jwks_uri               :string
#  scopes                 :string           default("openid email profile")
#  uid_claim              :string           default("sub"), not null
#  email_claim            :string           default("email")
#  name_claim             :string           default("name")
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
FactoryBot.define do
  factory :oidc_configuration do
    issuer { "https://auth.example.com" }
    client_id { "canine-client" }
    client_secret { "super-secret-key" }
    authorization_endpoint { nil }
    token_endpoint { nil }
    userinfo_endpoint { nil }
    jwks_uri { nil }
    scopes { "openid email profile" }
    uid_claim { "sub" }
    email_claim { "email" }
    name_claim { "name" }
  end
end
