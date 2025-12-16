require 'rails_helper'

RSpec.describe SSO::SyncUserTeams do
  let(:account) { create(:account) }
  let(:sso_provider) { create(:sso_provider, account: account) }

  describe '.call' do
    it 'creates user, teams, and team memberships' do
      create(:team, account: account, name: 'Existing')

      result = described_class.call(
        email: 'new@example.com',
        team_names: [ { name: 'Existing' }, { name: 'NewTeam' } ],
        account: account,
        sso_provider: sso_provider,
        uid: 'user-uid-123',
        create_teams: true
      )

      expect(result).to be_success
      expect(result.user.email).to eq('new@example.com')
      expect(account.teams.pluck(:name)).to match_array(%w[Existing NewTeam])
      expect(result.user.teams).to match_array(account.teams)
    end

    it 'removes user from teams they are no longer part of on remote source' do
      user = create(:user, email: 'existing@example.com')
      team_to_keep = create(:team, account: account, name: 'KeepTeam')
      team_to_remove = create(:team, account: account, name: 'RemoveTeam')
      create(:team_membership, user: user, team: team_to_keep)
      create(:team_membership, user: user, team: team_to_remove)
      create(:account_user, account: account, user: user)
      create(:provider, user: user, sso_provider: sso_provider, uid: 'existing-uid', provider: sso_provider.name)

      result = described_class.call(
        email: 'existing@example.com',
        team_names: [ { name: 'KeepTeam' } ],
        account: account,
        sso_provider: sso_provider,
        uid: 'existing-uid',
        create_teams: true
      )

      expect(result).to be_success
      expect(result.user.teams.reload).to contain_exactly(team_to_keep)
    end

    it 'does not remove user from teams in other accounts' do
      other_account = create(:account)
      user = create(:user, email: 'existing@example.com')
      team_in_account = create(:team, account: account, name: 'AccountTeam')
      team_in_other = create(:team, account: other_account, name: 'OtherTeam')
      create(:team_membership, user: user, team: team_in_account)
      create(:team_membership, user: user, team: team_in_other)
      create(:account_user, account: account, user: user)
      create(:provider, user: user, sso_provider: sso_provider, uid: 'existing-uid', provider: sso_provider.name)

      result = described_class.call(
        email: 'existing@example.com',
        team_names: [],
        account: account,
        sso_provider: sso_provider,
        uid: 'existing-uid',
        create_teams: true
      )

      expect(result).to be_success
      expect(user.teams.reload).to contain_exactly(team_in_other)
    end
  end
end
