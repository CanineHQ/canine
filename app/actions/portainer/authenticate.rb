class Portainer::Authenticate
  extend LightService::Action

  expects :stack_manager, :user, :auth_code
  expects :username, default: nil

  executed do |context|
    stack_manager = context.stack_manager
    access_token = Portainer::Client.authenticate(
      auth_code: context.auth_code,
      username: context.username,
      provider_url: stack_manager.provider_url
    )
    context.user.providers.find_or_initialize_by(provider: "portainer").update!(access_token:)
  end
end
