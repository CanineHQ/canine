class Providers::CreateBitbucketProvider
  EXPECTED_SCOPES = %w[webhook repository user pullrequest].freeze
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    provider = context.provider

    if provider.username_param.blank?
      provider.errors.add(:username_param, "Atlassian account email is required")
      context.fail_and_return!("Atlassian account email is required")
      next
    end

    base_url = provider.api_base_url
    user_api_url = "#{base_url}/2.0/user"

    # Bitbucket API tokens use Basic Auth with email:api_token
    credentials = Base64.strict_encode64("#{provider.username_param}:#{provider.read_attribute(:access_token)}")
    response = HTTParty.get(user_api_url,
      headers: {
        "Authorization" => "Basic #{credentials}",
        "Accept" => "application/json"
      }
    )
    debugger

    if response.code == 401
      message = "Invalid email or API token"
      provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end

    if response.code != 200
      message = "Failed to validate credentials: #{response.body}"
      provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end

    # nickname = Bitbucket username (from API response, used for display)
    # email = Atlassian account email (from form input, used for Basic Auth)
    username = response["username"] || response["display_name"]

    provider.auth = {
      "info" => {
        "nickname" => username,
        "email" => provider.username_param
      }
    }.merge(response.parsed_response).to_json

    provider.save!
  rescue Errno::ECONNREFUSED, SocketError => e
    message = "Could not connect to Bitbucket server: #{e.message}"
    context.provider.errors.add(:registry_url, message)
    context.fail_and_return!(message)
  end
end
