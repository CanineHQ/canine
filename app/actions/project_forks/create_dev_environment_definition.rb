class ProjectForks::CreateDevEnvironmentDefinition
  extend LightService::Action

  expects :parent_project
  promises :definition

  executed do |context|
    parent = context.parent_project

    definition = parent.to_canine_config

    # Dev environments fork off the same branch as the parent
    definition["project"]["name"] = "#{parent.name}-dev-#{SecureRandom.hex(4)}"

    context.definition = definition
  end
end
