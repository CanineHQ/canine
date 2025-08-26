class Avo::Resources::BuildCloud < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :cluster, as: :belongs_to
    field :namespace, as: :text
    field :status, as: :number
    field :driver_version, as: :text
    field :webhook_url, as: :text
    field :installation_metadata, as: :code
    field :installed_at, as: :date_time
    field :error_message, as: :textarea
  end
end
