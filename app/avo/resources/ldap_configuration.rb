class Avo::Resources::LdapConfiguration < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :host, as: :text
    field :port, as: :number
    field :encryption, as: :text
    field :base_dn, as: :text
    field :bind_dn, as: :text
    field :bind_password, as: :text
    field :uid_attribute, as: :text
    field :email_attribute, as: :text
    field :name_attribute, as: :text
    field :filter, as: :text
  end
end
