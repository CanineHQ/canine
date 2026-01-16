class Avo::Resources::Team < Avo::BaseResource
  self.includes = [ :account, :users ]
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
    field :name, as: :text, link_to_record: true
    field :slug, as: :text
    field :account, as: :belongs_to
    field :created_at, as: :date_time, sortable: true

    field :users, as: :has_many
    field :team_resources, as: :has_many
  end
end
