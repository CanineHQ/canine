class Avo::Resources::Account < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :owner, as: :belongs_to
    field :users, as: :has_many
    field :clusters, as: :has_many
    field :projects, as: :has_many, through: :clusters
    field :add_ons, as: :has_many, through: :clusters
  end
end
