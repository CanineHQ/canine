class Providers::CreateGithubProvider
  EXPECTED_SCOPES = [ "repo", "write:packages" ]
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    client = Git::Github::Client.build_client(
      access_token: context.provider.access_token,
      api_base_url: context.provider.api_base_url
    )
    username = client.user[:login]
    context.provider.auth = {
      info: {
        nickname: username
      }
    }.to_json

    # Skip scope validation for enterprise (some GHE instances don't expose scopes)
    unless context.provider.enterprise?
      if (client.scopes & EXPECTED_SCOPES).sort != EXPECTED_SCOPES.sort
        message = "Invalid scopes. Please check that your personal access token has the following scopes: #{EXPECTED_SCOPES.join(", ")}"
        context.fail_and_return!(message)
        context.provider.errors.add(:access_token, message)
        next
      end
    end
    context.provider.save!
  rescue Octokit::Unauthorized
    message = "Invalid access token"
    context.provider.errors.add(:access_token, message)
    context.fail_and_return!(message)
  rescue Faraday::ConnectionFailed => e
    message = "Could not connect to GitHub server: #{e.message}"
    context.provider.errors.add(:registry_url, message)
    context.fail_and_return!(message)
  end
end
