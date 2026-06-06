class Onboarding::Create
  extend LightService::Organizer

  def self.call(params)
    with(
      account_name: params[:account][:name],
      email: params[:user][:email],
      password: params[:user][:password],
      connect_cluster: params[:connect_cluster] == "1",
      install_build_cloud: params[:install_build_cloud] == "1",
    ).reduce(actions)
  end

  def self.actions
    [
      Onboarding::CreateUserWithAccount,
      Onboarding::CreateInClusterCluster
    ]
  end
end
