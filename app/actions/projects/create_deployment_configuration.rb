class Projects::BuildDeploymentConfiguration
  extend LightService::Action
  expects :project

  executed do |context|
    project = context.project
    project.build_deployment_configuration!(deployment_method: "helm")
  end
end