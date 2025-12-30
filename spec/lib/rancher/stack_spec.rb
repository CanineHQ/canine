require "rails_helper"
require "webmock/rspec"
require 'support/shared_contexts/with_rancher'

RSpec.describe Rancher::Stack do
  include_context 'with rancher'
  let(:account) { create(:account) }
  let(:stack_manager) { create(:stack_manager, :rancher, account: account) }
  let!(:rancher_provider) { create(:provider, :rancher, user: account.owner) }
  let(:client) {
    Rancher::Client.new(
      stack_manager.provider_url,
      Rancher::Client::ApiKey.new(account.owner.rancher_access_token)
    )
  }
  let(:rancher_stack) { described_class.new(stack_manager)._connect_with_client(client) }

  describe "#retrieve_access_token" do
    it "returns user rancher_access_token when RBAC is enabled" do
      user = account.owner
      stack = described_class.new(stack_manager)
      expect(stack.retrieve_access_token(user).token).to eq(user.rancher_access_token)
    end

    it "returns stack_manager access_token when RBAC is disabled" do
      stack_manager.update(enable_role_based_access_control: false)
      user = account.owner
      stack = described_class.new(stack_manager)
      expect(stack.retrieve_access_token(user).token).to eq(stack_manager.access_token)
    end
  end

  describe "#sync_clusters" do
    it "fetches clusters and creates/updates only active clusters" do
      rancher_stack.sync_clusters
      # The fixture has 3 clusters but only 2 are active
      expect(account.clusters.count).to eq(2)
    end

    it "creates clusters with correct external_id" do
      rancher_stack.sync_clusters
      expect(account.clusters.pluck(:external_id)).to contain_exactly("c-m-xxxxxxxx", "c-m-yyyyyyyy")
    end
  end

  describe "#fetch_kubeconfig" do
    let(:cluster) { create(:cluster, account: account, external_id: "c-m-xxxxxxxx") }

    it "generates kubeconfig for specific cluster" do
      result = rancher_stack.fetch_kubeconfig(cluster)

      expect(result["apiVersion"]).to eq("v1")
      expect(result["kind"]).to eq("Config")
      expect(result["clusters"]).to be_present
    end
  end

  describe "#provides_clusters?" do
    it "returns true" do
      expect(rancher_stack.provides_clusters?).to be true
    end
  end

  describe "#provides_registries?" do
    it "returns false for Rancher" do
      expect(rancher_stack.provides_registries?).to be false
    end
  end

  describe "#provides_logs?" do
    it "returns true" do
      expect(rancher_stack.provides_logs?).to be true
    end
  end
end
