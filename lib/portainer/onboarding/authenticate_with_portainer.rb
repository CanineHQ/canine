class Portainer::Onboarding::AuthenticateWithPortainer
  extend LightService::Action
  expects :username, :password, :provider_url
  promises :jwt

  executed do |context|
    context.jwt = Portainer::Client.authenticate(
      auth_code: context.password,
      username: context.username,
      provider_url: context.provider_url
    )
  end
end
