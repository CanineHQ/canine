class ProjectForks::CreateFromCanineConfig
  extend LightService::Action
  expects :canine_config, :project

  executed do |context|
    context.canine_config.services.each do |service_config|
    end

    context.canine_config.environment_variables.each do |environment_variable|
    end
  end
end
