class Onboarding::Create
  extend LightService::Organizer

  def self.call(params)
    with(
      account_name: params[:account][:name],
      email: params[:user][:email],
      password: params[:user][:password],
    ).reduce(actions)
  end

  def self.actions
    [
      Onboarding::CreateUserWithAccount,
      Onboarding::CreateInClusterCluster
    ]
  end
end
