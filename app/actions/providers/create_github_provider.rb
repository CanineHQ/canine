class Providers::CreateGithubProvider
  EXPECTED_SCOPES = [ "repo", "write:packages" ]
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    client_options = { access_token: context.provider.access_token }
    if context.provider.enterprise?
      client_options[:api_endpoint] = "#{context.provider.api_base_url}/api/v3/"
    end
    client = Octokit::Client.new(client_options)
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
