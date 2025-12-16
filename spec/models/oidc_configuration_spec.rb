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
require 'rails_helper'

RSpec.describe OIDCConfiguration, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      config = build(:oidc_configuration)
      expect(config).to be_valid
    end

    it "requires issuer, client_id, and client_secret" do
      config = build(:oidc_configuration, issuer: nil, client_id: nil, client_secret: nil)
      expect(config).not_to be_valid
      expect(config.errors[:issuer]).to be_present
      expect(config.errors[:client_id]).to be_present
      expect(config.errors[:client_secret]).to be_present
    end
  end

  describe "#discovery_url" do
    it "returns the well-known configuration URL" do
      config = build(:oidc_configuration, issuer: "https://auth.example.com")
      expect(config.discovery_url).to eq("https://auth.example.com/.well-known/openid-configuration")
    end

    it "strips trailing slash from issuer" do
      config = build(:oidc_configuration, issuer: "https://auth.example.com/")
      expect(config.discovery_url).to eq("https://auth.example.com/.well-known/openid-configuration")
    end
  end

  describe "#uses_discovery?" do
    it "returns true when endpoints are blank" do
      config = build(:oidc_configuration, authorization_endpoint: nil, token_endpoint: nil)
      expect(config.uses_discovery?).to be true
    end

    it "returns false when endpoints are configured" do
      config = build(:oidc_configuration,
        authorization_endpoint: "https://auth.example.com/authorize",
        token_endpoint: "https://auth.example.com/token"
      )
      expect(config.uses_discovery?).to be false
    end
  end
end
