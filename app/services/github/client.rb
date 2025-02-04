class Github::Client
  WEBHOOK_SECRET = ENV["OMNIAUTH_GITHUB_WEBHOOK_SECRET"]

  attr_accessor :client, :project
  def initialize(project)
    @project = project
    @client = Octokit::Client.new(access_token: project.github_access_token)
  end

  def repository_exists?
    client.repository?(project.repository_url)
  end

  def register_webhook!
    client.create_hook(
      project.repository_url,
      "web",
      {
        url: Rails.application.routes.url_helpers.inbound_webhooks_github_index_url,
        content_type: "json",
        secret: webhook_secret
      },
      {
        events: [ "push" ],
        active: true
      }
    )
  end

  def webhook_exists?
    webhook.present?
  end

  def remove_webhook!
    if webhook_exists?
      client.remove_hook(project.repository_url, hook.id)
    end
  end

  def webhook
    webhooks.find { |h| h.config.url.include?(Rails.application.routes.url_helpers.inbound_webhooks_github_index_path) }
  end

  def webhooks
    client.hooks(project.repository_url)
  end

  private

  def webhook_secret
    return WEBHOOK_SECRET if WEBHOOK_SECRET.present?
    credentials = Rails.application.credentials.dig(Rails.env, :github) || {}
    credentials[:webhook_secret]
  end
end
