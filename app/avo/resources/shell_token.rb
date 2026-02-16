class Avo::Resources::ShellToken < Avo::BaseResource
  self.visible_on_sidebar = false

  def fields
    field :id, as: :id
    field :token, as: :text
    field :user, as: :belongs_to
    field :cluster, as: :belongs_to
    field :pod_name, as: :text
    field :namespace, as: :text
    field :container, as: :text
    field :expires_at, as: :date_time
  end
end
