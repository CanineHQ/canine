class ProjectForks::CreateDevelopmentEnvironmentDefinition
  extend LightService::Action

  WORKSPACE_SIZE = "5Gi"
  DEFAULT_ACCESS_MODE = "read_write_once"

  expects :parent_project, :current_user, :git_provider
  promises :definition

  executed do |context|
    parent = context.parent_project
    development_environment_configuration = parent.development_environment_configuration

    definition = parent.to_canine_config

    # Dev environments fork off the same branch as the parent
    suffix = SecureRandom.hex(4)
    definition["project"]["name"] = "#{parent.name}-dev-#{suffix}"

    # Use the dev Dockerfile when the build type is dockerfile
    if development_environment_configuration&.dockerfile_path.present? && definition.dig("build_configuration", "build_type") == "dockerfile"
      definition["build_configuration"]["dockerfile_path"] = development_environment_configuration.dockerfile_path
    end

    # Strip parent domains — the dev environment will get its own oncanine.run domain
    definition["services"]&.each { |s| s.delete("domains") }

    # Inject git environment variables for the dev environment
    definition["environment_variables"] ||= []

    definition["environment_variables"] << {
      "name" => "GIT_REPOSITORY_URL",
      "value" => parent.link_to_view,
      "storage_type" => "config"
    }

    git_provider = context.git_provider
    if git_provider.present?
      definition["environment_variables"] << {
        "name" => "GIT_ACCESS_TOKEN",
        "value" => git_provider.access_token,
        "storage_type" => "secret"
      }
    end

    user = context.current_user
    definition["environment_variables"] << {
      "name" => "GIT_USER_NAME",
      "value" => user.name.to_s,
      "storage_type" => "config"
    }
    definition["environment_variables"] << {
      "name" => "GIT_USER_EMAIL",
      "value" => user.email,
      "storage_type" => "config"
    }

    # Create workspace volume for the dev environment
    definition["volumes"] ||= []

    if development_environment_configuration&.workspace_mount_path.present?
      definition["volumes"] << {
        "name" => "workspace-#{suffix}",
        "size" => WORKSPACE_SIZE,
        "mount_path" => development_environment_configuration.workspace_mount_path,
        "access_mode" => DEFAULT_ACCESS_MODE
      }
    end

    context.definition = definition
  end
end
