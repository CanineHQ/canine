class Providers::CreateGitlabProvider
  EXPECTED_SCOPES = %w[ api read_repository read_registry write_registry ]
  GITLAB_PAT_API_URL = "https://gitlab.com/api/v4/personal_access_tokens/self"
  GITLAB_USER_API_URL = "https://gitlab.com/api/v4/user"
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    response = HTTParty.get(GITLAB_PAT_API_URL,
      headers: {
        "Authorization" => "Bearer #{context.provider.access_token}"
      },
    )
    if response.code != 200
      message = "Invalid access token"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end

    if (response["scopes"] & EXPECTED_SCOPES).sort != EXPECTED_SCOPES.sort
      message = "Invalid scopes. Please check that your personal access token has the following scopes: #{EXPECTED_SCOPES.join(", ")}"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end
    # Get username data

    response = HTTParty.get(GITLAB_USER_API_URL,
      headers: {
        "Authorization" => "Bearer #{context.provider.access_token}"
      },
    )
    if response.code != 200
      message = "Something went wrong while getting the user data"
      context.provider.errors.add(:access_token, message)
      context.fail_and_return!(message)
      next
    end
    body = {"info" => { "nickname" => response["username"] } }.merge(response).to_json
    context.provider.auth = body

    context.provider.save!
  end
end
