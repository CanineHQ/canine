class Avo::Resources::Project < Avo::BaseResource
  def fields
    field :id, as: :id
    # Generated fields from model
    field :name, as: :text
    field :repository_url, as: :text
    field :branch, as: :text
    field :status, as: :select, options: Project.statuses.keys.map { |status| [ status.humanize, status ] }
    field :autodeploy, as: :boolean
    field :docker_command, as: :text
    field :dockerfile_path, as: :text
    field :docker_build_context_directory, as: :text
    field :container_registry_url, as: :text
    field :predeploy_command, as: :text

    field :account, as: :belongs_to
    field :cluster, as: :belongs_to
    field :services, as: :has_many
  end
end
