class Portainer::Onboarding::Create
  extend LightService::Organizer

  def self.post_create
    [
      Portainer::SyncClusters,
      Portainer::SyncRegistries
    ]
  end

  def self.call(params)
    with(
      username: params[:user][:username],
      password: params[:user][:password],
      provider_url: params[:stack_manager][:provider_url],
      account_name: params[:account][:name],
    ).reduce(
      Portainer::Onboarding::ValidateBootMode,
      Portainer::Onboarding::AuthenticateWithPortainer,
      Portainer::Onboarding::CreateUserWithStackManager,
      *post_create,
    )
  end
end
