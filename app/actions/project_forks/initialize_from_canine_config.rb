class ProjectForks::InitializeFromCanineConfig
  extend LightService::Action
  expects :project_fork

  executed do |context|
    # Skip this action if no canine_config is stored
    next if context.project_fork.canine_config.blank?

    config_data = context.project_fork.canine_config

    # Create services from the stored config
    config_data['services']&.each do |service_config|
      params = Service.permitted_params(ActionController::Parameters.new(service: service_config))
      service = context.project_fork.child_project.services.build(params)
      service.save!
    end

    # Create environment variables from the stored config
    config_data['environment_variables']&.each do |env_var|
      context.project_fork.child_project.environment_variables.create!(
        name: env_var['name'],
        value: env_var['value']
      )
    end
  end
end
