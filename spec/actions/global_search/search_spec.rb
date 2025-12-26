# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GlobalSearch::Search do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account:, user:) }
  let!(:cluster) { create(:cluster, account:, name: "production-cluster") }
  let!(:project1) { create(:project, cluster:, account:, name: "api-service") }
  let!(:project2) { create(:project, cluster:, account:, name: "web-app") }
  let!(:add_on) { create(:add_on, cluster:, name: "redis-cache") }

  describe '.execute' do
    it 'returns matching projects, clusters, and add_ons with proper includes' do
      result = described_class.execute(account_user:, query: "api", limit: 5)

      expect(result).to be_success
      expect(result.projects).to include(project1)
      expect(result.projects).not_to include(project2)
      expect(result.clusters).to be_empty
      expect(result.add_ons).to be_empty

      result = described_class.execute(account_user:, query: "production", limit: 5)
      expect(result.clusters).to include(cluster)
      expect(result.projects).to be_empty

      result = described_class.execute(account_user:, query: "redis", limit: 5)
      expect(result.add_ons).to include(add_on)
      expect(result.add_ons.first.association(:cluster)).to be_loaded

      result = described_class.execute(account_user:, query: "", limit: 5)
      expect(result.projects).to eq([])
      expect(result.clusters).to eq([])
      expect(result.add_ons).to eq([])

      result = described_class.execute(account_user:, query: "   ", limit: 5)
      expect(result.projects).to eq([])

      3.times { |i| create(:project, cluster:, account:, name: "test-project-#{i}") }
      result = described_class.execute(account_user:, query: "test", limit: 2)
      expect(result.projects.size).to eq(2)
    end
  end
end
