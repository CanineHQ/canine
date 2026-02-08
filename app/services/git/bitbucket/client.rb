class Git::Bitbucket::Client < Git::Client
  BITBUCKET_WEBHOOK_SECRET = ENV["BITBUCKET_WEBHOOK_SECRET"]
  attr_accessor :access_token, :email, :repository_url, :api_base_url

  def self.from_project(project)
    provider = project.project_credential_provider.provider
    raise "Project is not a Bitbucket project" unless provider.bitbucket?
    new(
      email: provider.email,
      access_token: provider.access_token,
      repository_url: project.repository_url,
      api_base_url: provider.api_base_url
    )
  end

  def initialize(access_token:, repository_url:, email: nil, api_base_url: nil)
    @email = email
    @access_token = access_token
    @repository_url = repository_url
    @api_base_url = api_base_url || "https://api.bitbucket.org"
  end

  def bitbucket_api_base
    "#{@api_base_url}/2.0"
  end

  def repository_exists?
    repository.present? && repository["uuid"].present?
  end

  def commits(branch)
    response = HTTParty.get(
      "#{bitbucket_api_base}/repositories/#{repository_url}/commits?include=#{branch}",
      headers: auth_headers
    )
    unless response.success?
      raise "Failed to fetch commits: #{response.body}"
    end

    (response["values"] || []).map do |commit|
      Git::Common::Commit.new(
        sha: commit["hash"],
        message: commit["message"],
        author_name: commit.dig("author", "user", "display_name") || commit.dig("author", "raw")&.split("<")&.first&.strip,
        author_email: extract_email(commit.dig("author", "raw")),
        authored_at: DateTime.parse(commit["date"]),
        committer_name: commit.dig("author", "user", "display_name") || commit.dig("author", "raw")&.split("<")&.first&.strip,
        committer_email: extract_email(commit.dig("author", "raw")),
        committed_at: DateTime.parse(commit["date"]),
        url: commit.dig("links", "html", "href")
      )
    end
  end

  def can_write_webhooks?
    webhooks
    true
  rescue StandardError
    false
  end

  def register_webhook!
    return if webhook_exists?

    response = HTTParty.post(
      "#{bitbucket_api_base}/repositories/#{repository_url}/hooks",
      headers: auth_headers.merge("Content-Type" => "application/json"),
      body: {
        description: "Canine autodeploy webhook",
        url: Rails.application.routes.url_helpers.inbound_webhooks_bitbucket_index_url,
        active: true,
        secret: BITBUCKET_WEBHOOK_SECRET,
        events: [ "repo:push" ]
      }.to_json
    )
    unless response.success?
      raise "Failed to register webhook: #{response.body}"
    end
    response.parsed_response
  end

  def webhooks
    response = HTTParty.get(
      "#{bitbucket_api_base}/repositories/#{repository_url}/hooks",
      headers: auth_headers
    )
    return [] unless response.success?

    response["values"] || []
  end

  def webhook_exists?
    webhook.present?
  end

  def webhook
    webhooks.find { |h| h["url"]&.include?(Rails.application.routes.url_helpers.inbound_webhooks_bitbucket_index_path) }
  end

  def remove_webhook!
    return unless webhook_exists?

    HTTParty.delete(
      "#{bitbucket_api_base}/repositories/#{repository_url}/hooks/#{webhook['uuid']}",
      headers: auth_headers
    )
  end

  def pull_requests
    response = HTTParty.get(
      "#{bitbucket_api_base}/repositories/#{repository_url}/pullrequests",
      headers: auth_headers
    )
    return [] unless response.success?

    (response["values"] || []).map do |pr|
      Git::Common::PullRequest.new(
        id: pr["id"],
        title: pr["title"],
        number: pr["id"],
        user: pr.dig("author", "display_name") || pr.dig("author", "nickname"),
        url: pr.dig("links", "html", "href"),
        branch: pr.dig("source", "branch", "name"),
        created_at: DateTime.parse(pr["created_on"]),
        updated_at: DateTime.parse(pr["updated_on"])
      )
    end
  end

  def pull_request_status(pr_number)
    response = HTTParty.get(
      "#{bitbucket_api_base}/repositories/#{repository_url}/pullrequests/#{pr_number}",
      headers: auth_headers
    )
    return "not_found" unless response.success?

    response.parsed_response["state"]&.downcase
  end

  def get_file(file_path, branch)
    response = HTTParty.get(
      "#{bitbucket_api_base}/repositories/#{repository_url}/src/#{branch}/#{file_path}",
      headers: auth_headers
    )
    response.success? ? Git::Common::File.new(file_path, response.body, branch) : nil
  end

  private

  def repository
    @repository ||= begin
      response = HTTParty.get(
        "#{bitbucket_api_base}/repositories/#{repository_url}",
        headers: auth_headers
      )
      response.success? ? response.parsed_response : {}
    end
  end

  def auth_headers
    encoded = Base64.strict_encode64("#{email}:#{access_token}")
    { "Authorization" => "Basic #{encoded}" }
  end

  def extract_email(raw_author)
    return nil unless raw_author
    match = raw_author.match(/<([^>]+)>/)
    match ? match[1] : nil
  end
end
