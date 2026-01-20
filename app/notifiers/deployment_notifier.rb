class DeploymentNotifier < ApplicationNotifier
  required_params :project, :deployment

  def message
    deployment = params[:deployment]
    project = params[:project]

    case deployment.status
    when "in_progress"
      "Deployment started for #{project.name}"
    when "completed"
      "Deployment completed for #{project.name}"
    when "failed"
      "Deployment failed for #{project.name}"
    else
      "Deployment #{deployment.status} for #{project.name}"
    end
  end

  def success?
    params[:deployment].status == "completed"
  end
end
