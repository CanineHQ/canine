class Avo::Resources::OIDCConfiguration < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id
    field :issuer, as: :text, required: true, help: "OIDC provider issuer URL (e.g., https://auth.example.com)"
    field :client_id, as: :text, required: true, help: "OAuth 2.0 client ID"
    field :client_secret, as: :password, required: true, help: "OAuth 2.0 client secret"
    field :authorization_endpoint, as: :text, help: "Authorization endpoint URL (leave blank to use discovery)"
    field :token_endpoint, as: :text, help: "Token endpoint URL (leave blank to use discovery)"
    field :userinfo_endpoint, as: :text, help: "UserInfo endpoint URL (leave blank to use discovery)"
    field :jwks_uri, as: :text, help: "JWKS URI for token verification (leave blank to use discovery)"
    field :scopes, as: :text, help: "Space-separated scopes to request", default: "openid email profile"
    field :uid_claim, as: :text, required: true, help: "Claim to use as user identifier", default: "sub"
    field :email_claim, as: :text, help: "Claim for email address", default: "email"
    field :name_claim, as: :text, help: "Claim for full name", default: "name"

    field :sso_provider, as: :has_one
  end
end
