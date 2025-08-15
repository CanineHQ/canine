class Projects::DeployLatestCommit
  extend LightService::Action

  expects :project
  expects :current_user, default: nil
  expects :skip_build, default: false
  promises :project, :build

  executed do |context|
    # Fetch the latest commit from the default branch
    project = context.project
    current_user = context.current_user || project.account.owner
    if project.github?
      project_credential_provider = project.project_credential_provider
      client = Git::Client.from_project(project)
      commit = client.commits(project.branch).first
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

    context.build = build
    if context.skip_build
      build.info("Skipping build...", color: :yellow)
      build.update!(status: :completed)
      deployment = Deployment.create!(build:)
      Projects::DeploymentJob.perform_later(deployment, current_user)
    else
      Projects::BuildJob.perform_later(build, current_user)
    end
  end
end
