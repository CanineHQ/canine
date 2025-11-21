class Avo::Resources::SSOProvider < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :account, as: :belongs_to
    field :configuration, as: :text
    field :name, as: :text
    field :enabled, as: :boolean
  end
end
