class Portainer::Authenticate
  extend LightService::Action

  expects :stack_manager, :user, :auth_code
  expects :username, default: nil

  executed do |context|
    stack_manager = context.stack_manager
    portainer_user = Portainer::Client.authenticate(
      auth_code: context.auth_code,
      username: context.username,
      provider_url: stack_manager.provider_url
    )
    provider = context.user.providers.find_or_initialize_by(provider: "portainer")
    provider.auth = {
      info: {
        username: portainer_user.username
      }
    }.to_json
    provider.update!(access_token: portainer_user.jwt)
  end
end
