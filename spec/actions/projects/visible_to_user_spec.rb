require 'rails_helper'

RSpec.describe Projects::VisibleToUser do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let!(:account_user) { create(:account_user, account:, user:) }
  let!(:cluster) { create(:cluster, account:) }
  let!(:project1) { create(:project, cluster:, account:) }
  let!(:project2) { create(:project, cluster:, account:) }

  describe '.execute' do
    context 'when user is an admin (account owner)' do
      let(:team) { create(:team, account: account) }

      before do
        account.update!(owner: user)
        team # Create team so account has teams
      end

      it 'returns all projects in the account regardless of team membership' do
        result = described_class.execute(account_user: account_user)

        expect(result).to be_success
        expect(result.projects).to match_array([ project1, project2 ])
      end
    end

    context 'when account has no teams' do
      it 'returns all projects in the account' do
        result = described_class.execute(account_user: account_user)

        expect(result).to be_success
        expect(result.projects).to match_array([ project1, project2 ])
      end
    end

    context 'when account has teams' do
      let(:team) { create(:team, account: account) }
      let(:other_team) { create(:team, account: account) }
      let!(:project3) { create(:project, cluster: cluster) }

      context 'when user is not in any teams' do
        it 'returns no projects' do
          result = described_class.execute(account_user: account_user)

          expect(result).to be_success
          expect(result.projects).to be_empty
        end
      end

      context 'when user has direct project access via team' do
        before do
          team.users << user
          create(:team_resource, team: team, resourceable: project1)
        end

        it 'returns only projects granted to user teams' do
          result = described_class.execute(account_user: account_user)

          expect(result).to be_success
          expect(result.projects).to eq([ project1 ])
        end
      end

      context 'when user has cluster access via team' do
        let(:cluster2) { create(:cluster, account: account) }
        let!(:project4) { create(:project, cluster: cluster2) }
        let!(:project5) { create(:project, cluster: cluster2) }

        before do
          team.users << user
          create(:team_resource, team: team, resourceable: cluster2)
        end

        it 'returns all projects in the granted cluster' do
          result = described_class.execute(account_user: account_user)

          expect(result).to be_success
          expect(result.projects).to match_array([ project4, project5 ])
        end
      end

      context 'when user has both direct project and cluster access' do
        let(:cluster2) { create(:cluster, account: account) }
        let!(:project4) { create(:project, cluster: cluster2) }

        before do
          team.users << user
          create(:team_resource, team: team, resourceable: project1)
          create(:team_resource, team: team, resourceable: cluster2)
        end

        it 'returns all accessible projects without duplicates' do
          result = described_class.execute(account_user: account_user)

          expect(result).to be_success
          expect(result.projects).to match_array([ project1, project4 ])
        end
      end

      context 'when user is in multiple teams with different access' do
        before do
          team.users << user
          other_team.users << user
          create(:team_resource, team: team, resourceable: project1)
          create(:team_resource, team: other_team, resourceable: project2)
        end

        it 'returns projects from all teams user belongs to' do
          result = described_class.execute(account_user: account_user)

          expect(result).to be_success
          expect(result.projects).to match_array([ project1, project2 ])
        end
      end
    end
  end
end
