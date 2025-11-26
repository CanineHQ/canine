class Avo::Resources::OIDCConfiguration < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :issuer, as: :text
    field :client_id, as: :text
    field :client_secret, as: :text
    field :authorization_endpoint, as: :text
    field :token_endpoint, as: :text
    field :userinfo_endpoint, as: :text
    field :jwks_uri, as: :text
    field :scopes, as: :text
  end
end
