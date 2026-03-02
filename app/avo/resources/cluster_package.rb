class Avo::Resources::ClusterPackage < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :cluster, as: :belongs_to
    field :name, as: :text
    field :status, as: :number
    field :config, as: :code
    field :installed_at, as: :date_time
  end
end
