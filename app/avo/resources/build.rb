class Avo::Resources::Build < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :commit_message, as: :text
    field :project, as: :belongs_to
    field :deployment, as: :has_one
    field :created_at, as: :date_time
    field :repository_url, as: :text
    field :git_sha, as: :text
    field :status, as: :select, enum: ::Build.statuses
    field :commit_sha, as: :text
  end
end
