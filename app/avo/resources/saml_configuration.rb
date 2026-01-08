class Avo::Resources::SAMLConfiguration < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id
    field :idp_entity_id, as: :text, required: true, help: "Identity Provider's entity ID (issuer)"
    field :idp_sso_service_url, as: :text, required: true, help: "Identity Provider's Single Sign-On service URL"
    field :idp_cert, as: :textarea, required: true, help: "Identity Provider's X.509 certificate (PEM format)"
    field :idp_slo_service_url, as: :text, help: "Identity Provider's Single Logout service URL (optional)"
    field :name_identifier_format, as: :text, help: "NameID format for SAML assertions", default: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
    field :uid_attribute, as: :text, help: "SAML attribute for user identifier", default: "email"
    field :email_attribute, as: :text, help: "SAML attribute for email address", default: "email"
    field :name_attribute, as: :text, help: "SAML attribute for full name", default: "name"
    field :groups_attribute, as: :text, help: "SAML attribute for group membership (optional)"
    field :sp_entity_id, as: :text, help: "Service Provider entity ID (defaults to metadata URL)"
    field :authn_requests_signed, as: :boolean, help: "Sign authentication requests sent to IdP"
    field :want_assertions_signed, as: :boolean, help: "Require IdP to sign SAML assertions"

    field :sso_provider, as: :has_one
  end
end
