class SSO::SyncUserTeams
  extend LightService::Organizer
  def self.call(email, team_names, account)
    with(email:, team_names:, account:).reduce(
      SSO::CreateTeamsInAccount,
      SSO::CreateUserInAccount,
      SSO::SyncTeams,
    )
  end
end
