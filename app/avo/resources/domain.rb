class Avo::Resources::Domain < Avo::BaseResource
  def fields
    field :id, as: :id
    # Generated fields from model
    field :domain_name, as: :text
    field :status, as: :select, options: Domain.statuses.keys.map { |status| [ status.humanize, status ] }
    field :status_reason, as: :text
    field :service, as: :belongs_to
  end
end
