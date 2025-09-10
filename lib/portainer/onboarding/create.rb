class Portainer::Onboarding::Create
  extend LightService::Organizer

  def self.call(params)
    with(
      username: params[:user][:username],
      password: params[:user][:password],
      provider_url: params[:stack_manager][:provider_url],
    ).reduce(
      Portainer::Onboarding::ValidateBootMode,
      Portainer::Onboarding::AuthenticateWithPortainer,
      Portainer::Onboarding::CreateUserWithStackManager,
      # Sync clusters
      Portainer::SyncClusters
      # Sync registries
    )
  end
end
