class Avo::Resources::DevelopmentEnvironmentConfiguration < Avo::BaseResource
  self.title = :id
  self.visible_on_sidebar = -> { Flipper.enabled?(:cloud_dev_environment) }

  def fields
    field :id, as: :id

    heading "Project Configuration"
    field :project, as: :belongs_to, required: true
    field :enabled, as: :boolean, help: "Enable or disable the dev environment for this project"

    heading "Repository Settings"
    field :branch_name, as: :text, required: true,
          help: "Git branch to use for the dev environment (e.g., 'main', 'develop')",
          placeholder: "main"
    field :dockerfile_path, as: :text, required: true,
          help: "Path to the Dockerfile for the dev environment (e.g., './Dockerfile.dev')",
          placeholder: "./Dockerfile.dev"
    field :application_path, as: :text, required: true,
          help: "Mount path inside the container where code will be accessible",
          placeholder: "/app"

    heading "Authentication"
    field :anthropic_api_key, as: :password,
          help: "Project-level Anthropic API key (leave empty to use account-level key)"
    field :ssh_username, as: :text,
          help: "SSH username for connecting to dev environment",
          placeholder: "developer"
    field :ssh_password, as: :password,
          help: "SSH password (auto-generated if empty)"
    field :ssh_port, as: :number,
          help: "SSH port inside the container",
          placeholder: "2222"

    heading "Metadata"
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
end
