class Providers::CreateGitlabProvider
  EXPECTED_SCOPES = %w[ api read_repository read_registry write_registry ]
  EXPECTED_FINE_GRAINED_PERMISSIONS = [
    "Personal Access Token: Read",
    "User: Read",
    "Project: Read & Write",
    "Container Registry: Read & Write"
  ].freeze
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    base_url = context.provider.api_base_url
    pat_api_url = "#{base_url}/api/v4/personal_access_tokens/self"
    user_api_url = "#{base_url}/api/v4/user"
    headers = { "Authorization" => "Bearer #{context.provider.read_attribute(:access_token)}" }

    response = HTTParty.get(pat_api_url, headers:)

    if response.code == 403 && response.parsed_response&.dig("error") == "insufficient_granular_scope"
      message = "Fine-grained token is missing required permissions: #{EXPECTED_FINE_GRAINED_PERMISSIONS.join(", ")}"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end

    if response.code == 401
      message = "Invalid access token"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end

    # Skip scope validation for enterprise (some instances may have different scope requirements)
    if response.code == 200 && !context.provider.enterprise?
      if (response["scopes"] & EXPECTED_SCOPES).sort != EXPECTED_SCOPES.sort
        message = "Invalid scopes. Please check that your personal access token has the following scopes: #{EXPECTED_SCOPES.join(", ")}"
        context.provider.errors.add(:access_token, message)
        context.fail_and_return!(message)
        next
      end
    end

    # Get username data
    response = HTTParty.get(user_api_url, headers:)
    if response.code != 200
      message = "Something went wrong while getting the user data"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end
    body = { "info" => { "nickname" => response["username"] } }.merge(response).to_json
    context.provider.auth = body

    context.provider.save!
  rescue Errno::ECONNREFUSED, SocketError => e
    message = "Could not connect to GitLab server: #{e.message}"
    context.provider.errors.add(:registry_url, message)
    context.fail_and_return!(message)
  end
end
