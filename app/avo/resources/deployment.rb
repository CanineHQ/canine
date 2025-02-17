class Avo::Resources::Deployment < Avo::BaseResource
  def fields
    field :id, as: :id
    # Generated fields from model
    field :status, as: :select, options: Deployment.statuses.keys.map { |status| [ status.humanize, status ] }
    field :created_at, as: :datetime
    field :updated_at, as: :datetime
    field :project, as: :belongs_to
  end
end
