class Avo::Resources::BuildPack < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :build_configuration, as: :belongs_to
    field :namespace, as: :text
    field :name, as: :text
    field :version, as: :text
    field :details, as: :code
  end
end
