class Avo::Resources::AddOn < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :cluster, as: :belongs_to
    field :status, as: :select, options: AddOn.statuses.keys.map { |status| [ status.humanize, status ] }
  end
end
