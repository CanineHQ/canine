class Avo::Resources::Notifier < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :project, as: :belongs_to
    field :name, as: :text
    field :provider_type, as: :number
    field :webhook_url, as: :text
    field :enabled, as: :boolean
  end
end
