class BuildNotifier < ApplicationNotifier
  required_params :project, :build

  def message
    build = params[:build]
    project = params[:project]
    build_url = deploy_project_deployments_url(project, build)

    case build.status
    when "in_progress"
      "Build started for #{project.name} (#{build.commit_sha[0..7]}). Track here: #{build_url}"
    when "completed"
      "Build completed for #{project.name} (#{build.commit_sha[0..7]}). See here: #{build_url}"
    when "failed"
      "Build failed for #{project.name} (#{build.commit_sha[0..7]}). See here: #{build_url}"
    else
      "Build #{build.status} for #{project.name}. See here: #{build_url}"
    end
  end

  def success?
    params[:build].status == "completed"
  end
end
