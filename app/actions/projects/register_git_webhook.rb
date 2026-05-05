class Projects::RegisterGitWebhook
  extend LightService::Action
  expects :project

  executed do |context|
    client = Git::Client.from_project(context.project)
    client.register_webhook!
  rescue StandardError => e
    Rails.logger.warn("Failed to register webhook for project #{context.project.id}: #{e.message}. Falling back to polling.")
  end
end
