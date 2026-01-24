class DeploymentNotifier < ApplicationNotifier
  required_params :project, :deployment

  def message
    deployment = params[:deployment]
    project = params[:project]
    deployment_url = deploy_project_deployments_url(project, deployment.build)

    case deployment.status
    when "in_progress"
      "Deployment started for #{project.name}. Track here: #{deployment_url}"
    when "completed"
      "Deployment completed for #{project.name}. See here: #{deployment_url}"
    when "failed"
      "Deployment failed for #{project.name}. See here: #{deployment_url}"
    else
      "Deployment #{deployment.status} for #{project.name}. See here: #{deployment_url}"
    end
  end

  def success?
    params[:deployment].status == "completed"
  end
end
