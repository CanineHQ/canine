class Avo::Resources::Cluster < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :account, as: :belongs_to
    field :add_ons, as: :has_many
    field :projects, as: :has_many
  end
end
