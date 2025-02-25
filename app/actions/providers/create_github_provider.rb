class Providers::CreateGithubProvider
  EXPECTED_SCOPES = [ "repo", "write:packages" ]
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    client = Octokit::Client.new(access_token: context.provider.access_token)
    username = client.user[:login]
    context.provider.auth = {
      info: {
        nickname: username
      }
    }.to_json

    if (client.scopes & EXPECTED_SCOPES).sort != EXPECTED_SCOPES.sort
      message = "Invalid scopes. Please check that your personal access token has the following scopes: #{EXPECTED_SCOPES.join(", ")}"
      context.fail_and_return!(message)
      context.provider.errors.add(:access_token, message)
      next
    end
    context.provider.save!
  rescue Octokit::Unauthorized
    message = "Invalid access token"
    context.provider.errors.add(:access_token, message)
    context.fail_and_return!(message)
  end
end
