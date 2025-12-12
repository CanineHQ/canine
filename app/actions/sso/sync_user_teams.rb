class SSO::SyncUserTeams
  extend LightService::Organizer
  def self.call(email:, team_names:, account:, sso_provider:, uid:, name: nil, create_teams: false)
    actions = []
    actions << SSO::CreateTeamsInAccount if create_teams
    actions << SSO::CreateUserInAccount
    actions << SSO::SyncTeams if create_teams

    with(email:, team_names:, account:, sso_provider:, uid:, name:).reduce(actions)
  end
end
