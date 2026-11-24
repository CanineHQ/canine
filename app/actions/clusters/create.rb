class Clusters::Create
  extend LightService::Organizer

  def self.call(params, account_user)
    with(
      params:,
      user: account_user.user,
      account: account_user.account,
    ).reduce(
      Clusters::ParseParams,
      Clusters::ValidateKubeConfig,
      Clusters::BootstrapServiceAccount,
      Clusters::Save,
    )
  end
end
