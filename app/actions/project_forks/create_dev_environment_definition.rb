class ProjectForks::CreateDevEnvironmentDefinition
  extend LightService::Action

  expects :parent_project
  promises :definition

  executed do |context|
    parent = context.parent_project
    dev_config = parent.development_environment_configuration

    definition = parent.to_canine_config

    # Dev environments fork off the same branch as the parent
    definition["project"]["name"] = "#{parent.name}-dev-#{SecureRandom.hex(4)}"

    # Use the dev Dockerfile when the build type is dockerfile
    if dev_config&.dockerfile_path.present? && definition.dig("build_configuration", "build_type") == "dockerfile"
      definition["build_configuration"]["dockerfile_path"] = dev_config.dockerfile_path
    end

    # Strip parent domains — the dev environment will get its own oncanine.run domain
    definition["services"]&.each { |s| s.delete("domains") }

    context.definition = definition
  end
end
