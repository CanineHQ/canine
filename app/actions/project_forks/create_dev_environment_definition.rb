class ProjectForks::CreateDevEnvironmentDefinition
  extend LightService::Action

  expects :parent_project
  promises :definition

  executed do |context|
    parent = context.parent_project
    dev_config = parent.development_environment_configuration

    definition = parent.to_canine_config

    # Dev environments fork off the same branch as the parent
    suffix = SecureRandom.hex(4)
    definition["project"]["name"] = "#{parent.name}-dev-#{suffix}"

    # Use the dev Dockerfile when the build type is dockerfile
    if dev_config&.dockerfile_path.present? && definition.dig("build_configuration", "build_type") == "dockerfile"
      definition["build_configuration"]["dockerfile_path"] = dev_config.dockerfile_path
    end

    # Strip parent domains — the dev environment will get its own oncanine.run domain
    definition["services"]&.each { |s| s.delete("domains") }

    # Inject Rover environment variables for the dev environment
    definition["environment_variables"] ||= []

    if dev_config&.workspace_mount_path.present?
      definition["environment_variables"] << {
        "name" => "ROVER_WORKSPACE_DIR",
        "value" => dev_config.workspace_mount_path,
        "storage_type" => "config"
      }
    end

    definition["environment_variables"] << {
      "name" => "ROVER_GIT_REPOSITORY_URL",
      "value" => parent.link_to_view,
      "storage_type" => "config"
    }

    if dev_config&.git_provider.present?
      definition["environment_variables"] << {
        "name" => "ROVER_GIT_ACCESS_TOKEN",
        "value" => dev_config.git_provider.access_token,
        "storage_type" => "secret"
      }
    end

    if dev_config&.llm_provider&.anthropic?
      definition["environment_variables"] << {
        "name" => "ROVER_ANTHROPIC_API_KEY",
        "value" => dev_config.llm_provider.access_token,
        "storage_type" => "secret"
      }
    end

    if dev_config&.llm_provider&.openai?
      definition["environment_variables"] << {
        "name" => "ROVER_OPENAI_API_KEY",
        "value" => dev_config.llm_provider.access_token,
        "storage_type" => "secret"
      }
    end

    # Create a volume for the workspace directory
    if dev_config&.workspace_mount_path.present?
      definition["volumes"] ||= []
      definition["volumes"] << {
        "name" => "rover-workspace-#{suffix}",
        "size" => "5Gi",
        "mount_path" => dev_config.workspace_mount_path,
        "access_mode" => "read_write_once"
      }
    end

    context.definition = definition
  end
end
