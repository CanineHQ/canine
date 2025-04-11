class Projects::ValidateGithubRepository
  extend LightService::Action

  expects :project, :project_credential_provider

  executed do |context|
    # The project is not created yet, so we can't call Github::Client.from_project
    client = Github::Client.new(
      access_token: context.project_credential_provider.access_token,
      repository_url: context.project.repository_url
    )
    unless client.repository_exists?
      context.project.errors.add(:repository_url, 'does not exist')
      context.fail_and_return!('Repository does not exist')
    end
    # Validate that we have permissions to create a webhook
    unless client.can_write_webhooks?
      context.project.errors.add(:repository_url, "does not have write access")
      context.fail_and_return!('Repository does not have write access')
    end
  rescue Octokit::Forbidden => e
    context.project.errors.add(:repository_url, "cannot be accessed, #{e.message}")
    context.fail_and_return!('Repository cannot be accessed')
  end
end
