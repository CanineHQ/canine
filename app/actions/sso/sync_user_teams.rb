class SSO::SyncUserTeams
  extend LightService::Organizer
  def self.call(email:, team_names:, account:, sso_provider:, uid:, name: nil)
    with(email:, team_names:, account:, sso_provider:, uid:, name:).reduce(
      SSO::CreateTeamsInAccount,
      SSO::CreateUserInAccount,
      SSO::SyncTeams,
    )
  end
end
