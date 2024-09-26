class Projects::RegisterGithubWebhook
  extend LightService::Action

  expects :project
  promises :project

  executed do |context|
    client = Octokit::Client.new(access_token: context.project.user.github_access_token)
    client.create_hook(
      context.project.repository_url,
      "web",
      {
        url: Rails.application.routes.url_helpers.inbound_webhooks_github_index_url,
        content_type: "json",
        secret: ENV.fetch("OMNIAUTH_GITHUB_WEBHOOK_SECRET",
                          Omniauth.credentials_for(:github)[:webhook_secret])
      },
      {
        events: [ "push" ],
        active: true
      }
    )
  end
end
