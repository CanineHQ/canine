class Projects::BuildDeploymentConfiguration
  extend LightService::Action
  expects :project

  executed do |context|
    project = context.project
    if project.deployment_configuration.nil?
      project.build_deployment_configuration(deployment_method: "helm")
    end
  end
end
