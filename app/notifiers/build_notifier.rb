class BuildNotifier < ApplicationNotifier
  required_params :project, :build

  def message
    build = params[:build]
    project = params[:project]

    case build.status
    when "in_progress"
      "Build started for #{project.name} (#{build.commit_sha[0..7]})"
    when "completed"
      "Build completed for #{project.name} (#{build.commit_sha[0..7]})"
    when "failed"
      "Build failed for #{project.name} (#{build.commit_sha[0..7]})"
    else
      "Build #{build.status} for #{project.name}"
    end
  end

  def success?
    params[:build].status == "completed"
  end
end
