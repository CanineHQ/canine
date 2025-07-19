class ProjectForks::InitializeFromCanineConfig
  extend LightService::Action
  expects :project_fork

  executed do |context|
    # Skip this action if no canine_config is stored
    next if context.project_fork.child_project.canine_config.blank?

    config_data = context.project_fork.child_project.canine_config
    definition = CanineConfig::Definition.new(config_data)

    # Create services from the definition
    definition.services.each do |service|
      service.project = context.project_fork.child_project
      service.save!
    end

    # Create environment variables from the definition
    definition.environment_variables.each do |env_var|
      context.project_fork.child_project.environment_variables.create!(
        name: env_var.name,
        value: env_var.value
      )
    end
  end
end
