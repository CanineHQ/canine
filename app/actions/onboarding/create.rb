class Onboarding::Create
  extend LightService::Organizer

  def self.call(params)
    with(
      account_name: params[:account][:name],
      email: params[:user][:email],
      password: params[:user][:password],
      connect_cluster: params[:connect_cluster] == "1",
      install_build_cloud: params[:install_build_cloud] == "1",
      packages: params[:packages],
    ).reduce(actions)
  end

  def self.actions
    [
      Onboarding::CreateUserWithAccount,
      reduce_if(->(ctx) { ctx[:connect_cluster] && K8::Connection.in_cluster? }, [
        Onboarding::CreateInClusterCluster
      ])
    ]
  end
end
