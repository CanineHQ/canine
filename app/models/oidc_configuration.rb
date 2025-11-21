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
class OIDCConfiguration < ApplicationRecord
  has_one :sso_provider, as: :configuration, dependent: :destroy
end
