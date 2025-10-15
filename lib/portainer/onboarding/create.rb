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
      account_name: params[:account][:name],
      provider_url: params[:stack_manager][:provider_url],
      access_token: params[:stack_manager][:access_code],
      enable_role_based_access_control: params[:stack_manager][:enable_role_based_access_control],
    ).reduce(
      Portainer::Onboarding::ValidateBootMode,
      Portainer::Onboarding::AuthenticateWithPortainer,
      Portainer::Onboarding::CreateUserWithStackManager,
      *post_create,
    )
  end
end
