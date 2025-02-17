class Avo::Resources::Service < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :service_type, as: :select, enum: ::Service.service_types
    field :command, as: :text
    field :name, as: :text
    field :replicas, as: :number
    field :healthcheck_url, as: :text
    field :allow_public_networking, as: :boolean
    field :status, as: :select, enum: ::Service.statuses
    field :last_health_checked_at, as: :date_time
    field :container_port, as: :number
    field :description, as: :textarea
    field :project, as: :belongs_to
    field :domains, as: :has_many
  end
end
