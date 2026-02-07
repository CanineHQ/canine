class Providers::CreateBitbucketProvider
  EXPECTED_SCOPES = %w[repository webhook pullrequest]
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    base_url = context.provider.api_base_url
    user_api_url = "#{base_url}/2.0/user"

    # Validate token by fetching user info
    response = HTTParty.get(user_api_url,
      headers: {
        "Authorization" => "Bearer #{context.provider.access_token}"
      }
    )

    if response.code == 401
      message = "Invalid access token"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end

    if response.code != 200
      message = "Failed to validate access token: #{response.body}"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end

    # Bitbucket doesn't expose token scopes via API like GitHub/GitLab
    # So we skip scope validation and trust the user configured it correctly

    username = response["username"] || response["display_name"]
    context.provider.auth = {
      "info" => { "nickname" => username }
    }.merge(response.parsed_response).to_json

    context.provider.save!
  rescue Errno::ECONNREFUSED, SocketError => e
    message = "Could not connect to Bitbucket server: #{e.message}"
    context.provider.errors.add(:registry_url, message)
    context.fail_and_return!(message)
  end
end
