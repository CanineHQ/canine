class Projects::RegisterGithubWebhook
  extend LightService::Action
  expects :project

  executed do |context|
    client = Github::Client.from_project(context.project)
    client.register_webhook!
  rescue Octokit::UnprocessableEntity => e
    next context if e.message.include?("Hook already exists")
    context.fail_and_return!("Failed to create webhook")
  end
end
