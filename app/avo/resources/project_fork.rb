class Avo::Resources::ProjectFork < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :new_project, as: :belongs_to
    field :base_project, as: :belongs_to
    field :external_id, as: :text
    field :clean_up_command, as: :textarea
  end
end
