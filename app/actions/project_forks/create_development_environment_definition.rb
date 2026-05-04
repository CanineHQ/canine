class ProjectForks::CreateDevelopmentEnvironmentDefinition
  extend LightService::Action

  expects :parent_project, :current_user
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

    # Inject Rover environment variables for the dev environment
    definition["environment_variables"] ||= []

    if development_environment_configuration&.workspace_mount_path.present?
      definition["environment_variables"] << {
        "name" => "ROVER_WORKSPACE_DIR",
        "value" => development_environment_configuration.workspace_mount_path,
        "storage_type" => "config"
      }
    end

    definition["environment_variables"] << {
      "name" => "ROVER_GIT_REPOSITORY_URL",
      "value" => parent.link_to_view,
      "storage_type" => "config"
    }

    if development_environment_configuration&.git_provider.present?
      definition["environment_variables"] << {
        "name" => "ROVER_GIT_ACCESS_TOKEN",
        "value" => development_environment_configuration.git_provider.access_token,
        "storage_type" => "secret"
      }
    end

    user = context.current_user
    definition["environment_variables"] << {
      "name" => "ROVER_GIT_USER_NAME",
      "value" => user.name.to_s,
      "storage_type" => "config"
    }
    definition["environment_variables"] << {
      "name" => "ROVER_GIT_USER_EMAIL",
      "value" => user.email,
      "storage_type" => "config"
    }

    # Create volumes for the dev environment
    definition["volumes"] ||= []

    # Rover home directory (persists history, configs)
    definition["volumes"] << {
      "name" => "rover-home-#{suffix}",
      "size" => "1Gi",
      "mount_path" => "/home/rover",
      "access_mode" => "read_write_once"
    }

    # Workspace volume (mounted in both rover and main container)
    if development_environment_configuration&.workspace_mount_path.present?
      definition["volumes"] << {
        "name" => "rover-workspace-#{suffix}",
        "size" => "5Gi",
        "mount_path" => development_environment_configuration.workspace_mount_path,
        "access_mode" => "read_write_once"
      }
    end

    context.definition = definition
  end
end
