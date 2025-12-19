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
      account_name: params[:account][:name],
      provider_url: params[:stack_manager][:provider_url],
      access_token: params[:stack_manager][:access_token],
      enable_role_based_access_control: params[:stack_manager][:enable_role_based_access_control],
      email: params[:user][:email],
      password: params[:user][:password],
      personal_access_token: params[:user]&.dig(:personal_access_token),
    ).reduce(
      Portainer::Onboarding::ValidateBootMode,
      Portainer::Onboarding::CreateUserWithStackManager,
      *post_create,
    )
  end
end
