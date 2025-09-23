class Portainer::Onboarding::AuthenticateWithPortainer
  extend LightService::Action
  expects :username, :password, :provider_url
  promises :portainer_user

  executed do |context|
    context.portainer_user = Portainer::Client.authenticate(
      auth_code: context.password,
      username: context.username,
      provider_url: context.provider_url
    )
  rescue Portainer::Client::AuthenticationError => e
    context.fail_and_return!(e.message)
  end
end
