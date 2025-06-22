class Projects::RegisterGitWebhook
  extend LightService::Action
  expects :project

  executed do |context|
    client = Git::Client.from_project(context.project)
    client.register_webhook!
  rescue StandardError => e
    context.project.errors.add(:repository_url, "Failed to create webhook: #{e.message}")
    context.fail_and_return!("Failed to create webhook: #{e.message}")
  end
end
