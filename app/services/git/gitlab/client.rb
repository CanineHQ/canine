class Git::Gitlab::Client < Git::Client
  GITLAB_API_BASE = "https://gitlab.com/api/v4"
  GITLAB_WEBHOOK_SECRET = ENV["GITLAB_WEBHOOK_SECRET"]
  attr_accessor :access_token, :repository_url

  def self.from_project(project)
    raise "Project is not a GitLab project" unless project.project_credential_provider.provider.gitlab?
    new(
      access_token: project.project_credential_provider.access_token,
      repository_url: project.repository_url
    )
  end

  def initialize(access_token:, repository_url:)
    @access_token = access_token
    @repository_url = repository_url
  end

  def repository_exists?
    repository.present?
  end

  def commits(branch)
    HTTParty.get(
      "#{GITLAB_API_BASE}/projects/#{encoded_url}/repository/commits?ref=#{branch}",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
  end

  def can_write_webhooks?
    true
  end

  def register_webhook!
    if webhook_exists?
      return
    end
    response = HTTParty.post(
      "#{GITLAB_API_BASE}/projects/#{encoded_url}/hooks",
      headers: { "Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json" },
      body: {
        url: Rails.application.routes.url_helpers.inbound_webhooks_gitlab_index_url,
        name: "canine-webhook",
        push_events: true,
        enable_ssl_verification: true,
        token: GITLAB_WEBHOOK_SECRET
      }.to_json
    )
    unless response.success?
      raise "Failed to register webhook: #{response.body}"
    end
    response.parsed_response
  end

  def webhooks
    response = HTTParty.get(
      "#{GITLAB_API_BASE}/projects/#{encoded_url}/hooks",
      headers: { "Authorization" => "Bearer #{access_token}" },
      format: :json
    )
  end

  def encoded_url
    URI.encode_www_form_component(repository_url)
  end

  def repository
    @repository ||= begin
      project_response = HTTParty.get(
        "#{GITLAB_API_BASE}/projects/#{encoded_url}",
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
    end
  end

  def access_token
    @access_token
  end

  def webhook_exists?
    webhook.present?
  end

  def webhook
    webhooks.find { |h| h['url'].include?(Rails.application.routes.url_helpers.inbound_webhooks_gitlab_index_path) }
  end

  def remove_webhook!
    if webhook_exists?
      HTTParty.delete(
        "#{GITLAB_API_BASE}/projects/#{encoded_url}/hooks/#{webhook['id']}",
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
    end
  end
end
