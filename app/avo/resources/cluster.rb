class Avo::Resources::Cluster < Avo::BaseResource
  self.search = {
    query: -> { query.ransack(name_cont: params[:q], m: "or").result(distinct: false) },
    item: -> {
      {
        title: record.name
      }
    }
  }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :status, as: :select, options: Cluster.statuses.keys.map { |status| [ status.humanize, status ] }
    field :account, as: :belongs_to
    field :add_ons, as: :has_many
    field :projects, as: :has_many
  end
end
