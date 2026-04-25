class Avo::Resources::DevelopmentEnvironment < Avo::BaseResource
  self.visible_on_sidebar = false

  def fields
    field :id, as: :id
    field :child_project, as: :belongs_to
    field :parent_project, as: :belongs_to
  end
end
