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
class OIDCConfiguration < ApplicationRecord
  has_one :sso_provider, as: :configuration, dependent: :destroy
  has_one :account, through: :sso_provider

  validates :issuer, presence: true
  validates :client_id, presence: true
  validates :client_secret, presence: true
  validates :uid_claim, presence: true

  def discovery_url
    "#{issuer.chomp('/')}/.well-known/openid-configuration"
  end

  def uses_discovery?
    authorization_endpoint.blank? && token_endpoint.blank?
  end
end
