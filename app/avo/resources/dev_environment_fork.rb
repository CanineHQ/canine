class Avo::Resources::DevEnvironmentFork < Avo::BaseResource
  self.visible_on_sidebar = false
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :child_project, as: :belongs_to
    field :parent_project, as: :belongs_to
  end
end
