class Projects::DeploymentJob < ApplicationJob
  def perform(deployment, user = nil)
    project = deployment.project
    project.intended_deployment = deployment
    deployment_method = project.deployment_configuration&.deployment_method || "legacy"

    service_class = case deployment_method
    when "helm"
      Deployments::HelmDeploymentService
    else
      Deployments::LegacyDeploymentService
    end

    service_class.new(deployment, user).deploy
  end
end
