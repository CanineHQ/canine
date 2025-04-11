class Github::Client
  WEBHOOK_SECRET = ENV["OMNIAUTH_GITHUB_WEBHOOK_SECRET"]

  attr_accessor :client, :repository_url

  def self.from_project(project)
    new(
      access_token: project.project_credential_provider.access_token,
      repository_url: project.repository_url
    )
  end

  def commits
    client.commits(repository_url)
  end

  def initialize(access_token:, repository_url:)
    @client = Octokit::Client.new(access_token:)
    @repository_url = repository_url
  end

  def repository_exists?
    client.repository?(repository_url)
  end

  def can_write_webhooks?
    webhooks
    true
  rescue Octokit::NotFound
    false
  end

  def register_webhook!
    client.create_hook(
      repository_url,
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
      client.remove_hook(repository_url, webhook.id)
    end
  end

  def webhook
    webhooks.find { |h| h.config.url.include?(Rails.application.routes.url_helpers.inbound_webhooks_github_index_path) }
  end

  def webhooks
    client.hooks(repository_url)
  end

  private

  def webhook_secret
    return WEBHOOK_SECRET if WEBHOOK_SECRET.present?
    credentials = Rails.application.credentials.dig(Rails.env, :github) || {}
    credentials[:webhook_secret]
  end
end
