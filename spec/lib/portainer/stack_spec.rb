require "rails_helper"
require "webmock/rspec"
require 'support/shared_contexts/with_portainer'

RSpec.describe Portainer::Stack do
  include_context 'with portainer'
  let(:account) { create(:account) }
  let(:stack_manager) { create(:stack_manager, account: account, access_token: "access_token") }
  let(:provider) { create(:provider, :portainer, user: account.owner) }
  let!(:portainer_provider) { create(:provider, :portainer, user: account.owner) }
  let(:client) { Portainer::Client.new(stack_manager.provider_url, account.owner.portainer_jwt) }
  let(:portainer_stack) { described_class.new(stack_manager)._connect_with_client(client) }

  describe "#retrieve_access_token" do
    it "returns user portainer_jwt when RBAC is enabled" do
      user = account.owner
      stack = described_class.new(stack_manager)
      expect(stack.retrieve_access_token(user)).to eq(user.portainer_jwt)
    end

    it "returns stack_manager access_token when RBAC is disabled" do
      stack_manager.update(enable_role_based_access_control: false)
      user = account.owner
      stack = described_class.new(stack_manager)
      expect(stack.retrieve_access_token(user)).to eq(stack_manager.access_token)
    end
  end

  describe "#sync_clusters" do
    it "fetches endpoints and creates/updates clusters" do
      portainer_stack.sync_clusters
      expect(account.clusters.count).to eq(2)
    end
  end

  describe "#fetch_kubeconfig" do
    let(:kubeconfig_json) { File.read(Rails.root.join("spec/resources/integrations/portainer/config.json")) }
    let(:cluster) { create(:cluster, account:, external_id: "1") }
    let(:client) { Portainer::Client.new(stack_manager.provider_url, account.owner.portainer_jwt) }

    before do
      allow(client).to receive(:get_kubernetes_config).and_return(JSON.parse(kubeconfig_json))
    end

    it "fetches kubernetes config and filters for the specific cluster" do
      result = portainer_stack.fetch_kubeconfig(cluster)

      expect(result["clusters"].length).to eq(1)
      expect(result["clusters"][0]["name"]).to eq("portainer-cluster-local")
      expect(result["clusters"][0]["cluster"]["server"]).to end_with("/api/endpoints/1/kubernetes")
    end

    it "filters contexts to match the selected cluster" do
      result = portainer_stack.fetch_kubeconfig(cluster)

      expect(result["contexts"].length).to eq(1)
      expect(result["contexts"][0]["name"]).to eq("portainer-ctx-local")
      expect(result["contexts"][0]["context"]["cluster"]).to eq("portainer-cluster-local")
    end

    it "sets the current context to the filtered context" do
      result = portainer_stack.fetch_kubeconfig(cluster)

      expect(result["current-context"]).to eq("portainer-ctx-local")
    end

    it "preserves other kubeconfig fields" do
      result = portainer_stack.fetch_kubeconfig(cluster)

      expect(result["apiVersion"]).to eq("v1")
      expect(result["kind"]).to eq("Config")
      expect(result["users"]).to be_present
    end
  end
end
