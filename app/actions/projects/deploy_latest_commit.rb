class Projects::DeployLatestCommit
  extend LightService::Action

  expects :project
  expects :current_user, default: nil
  promises :project

  executed do |context|
    # Fetch the latest commit from the default branch
    project = context.project
    current_user = context.current_user || project.account.owner
    if project.github?
      project_credential_provider = project.project_credential_provider
      client = Github::Client.from_project(project)
      commit = client.commits.first
      build = project.builds.create!(
        commit_sha: commit.sha,
        commit_message: commit.commit[:message],
        current_user:
      )
    else
      build = project.builds.create!(
        commit_sha: "latest",
        commit_message: "Deploying from #{project.repository_url}",
        current_user:
      )
    end

    Projects::BuildJob.perform_later(build)
  end
end
