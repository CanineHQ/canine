require 'rails_helper'

RSpec.describe AddOns::VisibleToUser do
  let!(:account) { create(:account) }
  let!(:user) { create(:user) }
  let!(:cluster) { create(:cluster, account: account) }

  before do
    account.users << user
  end

  describe '.execute' do
    context 'when account has no teams' do
      let!(:add_on1) { create(:add_on, cluster: cluster) }
      let!(:add_on2) { create(:add_on, cluster: cluster) }

      it 'returns all add_ons in the account' do
        result = described_class.execute(user: user, account: account)

        expect(result).to be_success
        expect(result.add_ons).to match_array([ add_on1, add_on2 ])
      end
    end

    context 'when account has teams' do
      let(:team) { create(:team, account: account) }
      let(:other_team) { create(:team, account: account) }
      let!(:add_on1) { create(:add_on, cluster: cluster) }
      let!(:add_on2) { create(:add_on, cluster: cluster) }
      let!(:add_on3) { create(:add_on, cluster: cluster) }

      context 'when user is not in any teams' do
        before do
          team # Force creation of team
        end

        it 'returns no add_ons' do
          result = described_class.execute(user: user, account: account.reload)

          expect(result).to be_success
          expect(result.add_ons).to be_empty
        end
      end

      context 'when user has direct add_on access via team' do
        before do
          team.users << user
          create(:team_resource, team: team, resourceable: add_on1)
        end

        it 'returns only add_ons granted to user teams' do
          result = described_class.execute(user: user, account: account)

          expect(result).to be_success
          expect(result.add_ons).to eq([ add_on1 ])
        end
      end

      context 'when user has cluster access via team' do
        let(:cluster2) { create(:cluster, account: account) }
        let!(:add_on4) { create(:add_on, cluster: cluster2) }
        let!(:add_on5) { create(:add_on, cluster: cluster2) }

        before do
          team.users << user
          create(:team_resource, team: team, resourceable: cluster2)
        end

        it 'returns all add_ons in the granted cluster' do
          result = described_class.execute(user: user, account: account)

          expect(result).to be_success
          expect(result.add_ons).to match_array([ add_on4, add_on5 ])
        end
      end

      context 'when user has both direct add_on and cluster access' do
        let(:cluster2) { create(:cluster, account: account) }
        let!(:add_on4) { create(:add_on, cluster: cluster2) }

        before do
          team.users << user
          create(:team_resource, team: team, resourceable: add_on1)
          create(:team_resource, team: team, resourceable: cluster2)
        end

        it 'returns all accessible add_ons without duplicates' do
          result = described_class.execute(user: user, account: account)

          expect(result).to be_success
          expect(result.add_ons).to match_array([ add_on1, add_on4 ])
        end
      end

      context 'when user is in multiple teams with different access' do
        before do
          team.users << user
          other_team.users << user
          create(:team_resource, team: team, resourceable: add_on1)
          create(:team_resource, team: other_team, resourceable: add_on2)
        end

        it 'returns add_ons from all teams user belongs to' do
          result = described_class.execute(user: user, account: account)

          expect(result).to be_success
          expect(result.add_ons).to match_array([ add_on1, add_on2 ])
        end
      end
    end
  end
end
