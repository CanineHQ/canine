class Avo::Resources::Deployment < Avo::BaseResource
  def fields
    field :id, as: :id
    # Generated fields from model
    field :status, as: :select, options: Deployment.statuses.keys.map { |status| [ status.humanize, status ] }
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
    field :project, as: :belongs_to
  end
end
