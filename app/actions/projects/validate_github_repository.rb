class Projects::ValidateGithubRepository
  extend LightService::Action

  expects :project
  promises :project

  executed do |context|
    client = Github::Client.new(context.project)
    unless client.repository_exists?
      context.project.errors.add(:repository_url, 'does not exist')
      context.fail_and_return!('Repository does not exist')
    end
  rescue Octokit::Forbidden => e
    context.project.errors.add(:repository_url, "cannot be accessed, #{e.message}")
    context.fail_and_return!('Repository cannot be accessed')
  end
end
