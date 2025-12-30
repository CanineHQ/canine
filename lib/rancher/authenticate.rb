# frozen_string_literal: true

class Rancher::Authenticate
  extend LightService::Action

  expects :stack_manager, :user, :api_key

  executed do |context|
    stack_manager = context.stack_manager

    # Validate the API key by making a test request
    client = Rancher::Client.new(
      stack_manager.provider_url,
      Rancher::Client::ApiKey.new(context.api_key)
    )

    rancher_user = client.current_user
    unless rancher_user
      context.fail_and_return!("Invalid Rancher API key")
      next
    end

    provider = context.user.providers.find_or_initialize_by(provider: Provider::RANCHER_PROVIDER)
    provider.auth = {
      info: {
        username: rancher_user.username
      }
    }.to_json
    provider.update!(access_token: context.api_key)
  end
end
