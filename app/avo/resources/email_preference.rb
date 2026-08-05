class Avo::Resources::EmailPreference < Avo::BaseResource
  self.visible_on_sidebar = false

  def fields
    field :id, as: :id
    field :service_health, as: :boolean
  end
end
