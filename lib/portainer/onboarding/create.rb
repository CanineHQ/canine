class Portainer::Onboarding::Create
  extend LightService::Organizer

  def self.call(params)
    with(
      username: params[:user][:username],
      password: params[:user][:password],
      provider_url: params[:stack_manager][:provider_url],
    ).reduce(
      Portainer::Onboarding::AuthenticateWithPortainer,
      Portainer::Onboarding::CreateUserWithStackManager,
    )
  end
end
