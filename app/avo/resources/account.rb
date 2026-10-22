class Avo::Resources::Account < Avo::BaseResource
  self.search = {
    query: -> { query.ransack(name_cont: params[:q], slug_cont: params[:q], m: "or").result(distinct: false) },
    item: -> {
      {
        title: record.name
      }
    }
  }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :owner, as: :belongs_to
    field :users, as: :has_many
    field :clusters, as: :has_many
    field :projects, as: :has_many, through: :clusters
    field :add_ons, as: :has_many, through: :clusters
    field :plan, as: :text, readonly: true, format_using: -> { record.complimentary? ? "pro (free)" : value }
    field :subscription_status, as: :text, readonly: true
  end

  def actions
    action Avo::Actions::CompProPlan
    action Avo::Actions::RemoveCompedProPlan
  end
end
