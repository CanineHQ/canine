class Git::Github::Client < Git::Client
  WEBHOOK_SECRET = ENV["OMNIAUTH_GITHUB_WEBHOOK_SECRET"]

  attr_accessor :client, :repository_url

  def self.from_project(project)
    new(
      access_token: project.project_credential_provider.access_token,
      repository_url: project.repository_url
    )
  end

  def commits(branch)
    client.commits(repository_url, branch)
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
    if webhook_exists?
      return
    end

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

  def pull_requests
    client.pull_requests(repository_url).map do |pr|
      Git::Common::PullRequest.new(
        id: pr.id,
        title: pr.title,
        branch: pr.head.ref,
        number: pr.number,
        user: pr.user.login,
        url: pr.html_url,
        created_at: pr.created_at,
        updated_at: pr.updated_at,
      )
    end
  end

  def pull_request_status(pr_number)
    pr = client.pull_request(repository_url, pr_number)
    pr.state
  rescue Octokit::NotFound
    'not_found'
  end

  def get_file(file_path, branch)
    contents = client.contents(repository_url, path: file_path, ref: branch)
    return nil if contents.nil?

    Git::Common::File.new(file_path, Base64.decode64(contents.content), branch)
  rescue Octokit::NotFound
    nil
  end

  private

  def webhook_secret
    return WEBHOOK_SECRET if WEBHOOK_SECRET.present?
    credentials = Rails.application.credentials.dig(Rails.env, :github) || {}
    credentials[:webhook_secret]
  end
end
