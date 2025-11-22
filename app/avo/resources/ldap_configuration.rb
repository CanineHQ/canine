class Avo::Resources::LDAPConfiguration < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id
    field :host, as: :text, required: true, help: "LDAP server hostname (e.g., ldap.example.com)"
    field :port, as: :number, required: true, help: "LDAP server port (default: 389 for plain/STARTTLS, 636 for LDAPS)"
    field :encryption, as: :select, required: true, help: "Encryption method", enum: {
      plain: "No encryption",
      simple_tls: "LDAPS (SSL/TLS)",
      start_tls: "STARTTLS"
    }, default: "plain"
    field :base_dn, as: :text, required: true, help: "Base DN for user searches (e.g., ou=users,dc=example,dc=com)"
    field :bind_dn, as: :text, help: "Bind DN for authentication (optional for anonymous bind)"
    field :bind_password, as: :password, help: "Bind password (optional for anonymous bind)"
    field :uid_attribute, as: :text, required: true, help: "Attribute for username (e.g., uid, sAMAccountName)", default: "uid"
    field :email_attribute, as: :text, help: "Attribute for email address", default: "mail"
    field :name_attribute, as: :text, help: "Attribute for full name", default: "cn"
    field :filter, as: :textarea, help: "Additional LDAP filter (optional)"

    field :sso_provider, as: :has_one
  end
end
