class Projects::DeployLatestCommit
  extend LightService::Action

  expects :project
  expects :current_user, default: nil
  promises :project

  executed do |context|
    # Fetch the latest commit from the default branch
    project = context.project
    current_user = context.current_user || project.account.owner
    client = Octokit::Client.new(access_token: project.account.github_access_token)
    commit = client.commits(project.repository_url).first

    build = project.builds.create!(
      commit_sha: commit.sha,
      commit_message: commit.commit[:message],
      current_user: current_user
    )
    Projects::BuildJob.perform_later(build)
  end
end
