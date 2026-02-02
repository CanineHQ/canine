class Git::Gitlab::Client < Git::Client
  GITLAB_WEBHOOK_SECRET = ENV["GITLAB_WEBHOOK_SECRET"]
  attr_accessor :access_token, :repository_url, :api_base_url

  def self.from_project(project)
    provider = project.project_credential_provider.provider
    raise "Project is not a GitLab project" unless provider.gitlab?
    new(
      access_token: provider.access_token,
      repository_url: project.repository_url,
      api_base_url: provider.api_base_url
    )
  end

  def self.build_client(access_token:, api_base_url: nil)
    new(access_token:, api_base_url:)
  end

  def initialize(access_token:, repository_url: nil, api_base_url: nil)
    @access_token = access_token
    @repository_url = repository_url
    @api_base_url = api_base_url || "https://gitlab.com"
  end

  def repos(page: 1, per_page: 20)
    response = HTTParty.get(
      "#{gitlab_api_base}/projects",
      headers: { "Authorization" => "Bearer #{access_token}" },
      query: { membership: true, page:, per_page:, order_by: "last_activity_at" }
    )
    unless response.success?
      raise "Failed to fetch repositories: #{response.body}"
    end

    response.map { |repo| GitlabRepository.new(repo) }
  end

  def search_repos(query)
    response = HTTParty.get(
      "#{gitlab_api_base}/projects",
      headers: { "Authorization" => "Bearer #{access_token}" },
      query: { membership: true, search: query, order_by: "last_activity_at" }
    )
    unless response.success?
      raise "Failed to search repositories: #{response.body}"
    end

    response.map { |repo| GitlabRepository.new(repo) }
  end

  class GitlabRepository
    attr_reader :id, :full_name, :name, :description, :web_url

    def initialize(data)
      @id = data["id"]
      @full_name = data["path_with_namespace"]
      @name = data["name"]
      @description = data["description"]
      @web_url = data["web_url"]
    end
  end

  def gitlab_api_base
    "#{@api_base_url}/api/v4"
  end

  def repository_exists?
    repository.present?
  end

  def commits(branch)
    response = HTTParty.get(
      "#{gitlab_api_base}/projects/#{encoded_url}/repository/commits?ref=#{branch}",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
    unless response.success?
      raise "Failed to fetch commits: #{response.body}"
    end

    response.map do |commit|
      Git::Common::Commit.new(
        sha: commit["id"],
        message: commit["message"],
        author_name: commit["author_name"],
        author_email: commit["author_email"],
        authored_at: DateTime.parse(commit["authored_date"]),
        committer_name: commit["committer_name"],
        committer_email: commit["committer_email"],
        committed_at: DateTime.parse(commit["committed_date"]),
        url: commit["web_url"]
      )
    end
  end

  def can_write_webhooks?
    true
  end

  def register_webhook!
    if webhook_exists?
      return
    end
    response = HTTParty.post(
      "#{gitlab_api_base}/projects/#{encoded_url}/hooks",
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
      "#{gitlab_api_base}/projects/#{encoded_url}/hooks",
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
        "#{gitlab_api_base}/projects/#{encoded_url}",
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
        "#{gitlab_api_base}/projects/#{encoded_url}/hooks/#{webhook['id']}",
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
    end
  end

  def pull_requests
    HTTParty.get(
      "#{gitlab_api_base}/projects/#{encoded_url}/merge_requests",
      headers: { "Authorization" => "Bearer #{access_token}" }
    ).map do |row|
      Git::Common::PullRequest.new(
        id: row["id"],
        title: row["title"],
        number: row["iid"],
        user: row["author"]["username"],
        url: row["web_url"],
        branch: row["source_branch"],
        created_at: DateTime.parse(row["created_at"]),
        updated_at: DateTime.parse(row["updated_at"])
      )
    end
  end

  def pull_request_status(pr_number)
    response = HTTParty.get(
      "#{gitlab_api_base}/projects/#{encoded_url}/merge_requests/#{pr_number}",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
    return 'not_found' unless response.success?

    response.parsed_response["state"]
  end

  def get_file(file_path, branch)
    response = HTTParty.get(
      "#{gitlab_api_base}/projects/#{encoded_url}/repository/files/#{URI.encode_www_form_component(file_path)}/raw?ref=#{branch}",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
    response.success? ? Git::Common::File.new(file_path, response.body, branch) : nil
  end
end
