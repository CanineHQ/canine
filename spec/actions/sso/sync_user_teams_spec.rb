require 'rails_helper'

RSpec.describe SSO::SyncUserTeams do
  let(:account) { create(:account) }

  describe '.call' do
    it 'creates user, teams, and team memberships' do
      create(:team, account: account, name: 'Existing')

      result = described_class.call('new@example.com', [ { name: 'Existing' }, { name: 'NewTeam' } ], account)

      expect(result).to be_success
      expect(result.user.email).to eq('new@example.com')
      expect(account.teams.pluck(:name)).to match_array(%w[Existing NewTeam])
      expect(result.user.teams).to match_array(account.teams)
    end
  end
end
