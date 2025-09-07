require "rails_helper"
require "webmock/rspec"

RSpec.describe Portainer::Stack do
  let(:account) { create(:account) }
  let(:stack_manager) { create(:stack_manager, account: account) }
  let(:provider) { create(:provider, :portainer, user: account.owner) }
  let(:portainer_stack) { described_class.new(stack_manager, account.owner) }

  describe "#initialize" do
    it "sets the stack_manager and user" do
      expect(portainer_stack.stack_manager).to eq(stack_manager)
      expect(portainer_stack.user).to eq(user)
    end
  end

  describe "#sync_clusters" do
    let(:endpoints_json) { File.read(Rails.root.join("spec/resources/integrations/portainer/endpoints.json")) }
    let(:client) { Portainer::Client.new(stack_manager.provider_url, account.owner.portainer_jwt) }

    before do
      allow(client).to receive(:get).with("/api/endpoints").and_return(JSON.parse(endpoints_json))
    end

    it "fetches endpoints and creates/updates clusters" do
      portainer_stack.sync_clusters
      expect(account.clusters.count).to eq(2)
    end
  end

  describe "#fetch_kubeconfig" do
    let(:kubeconfig_json) { File.read(Rails.root.join("spec/resources/integrations/portainer/kubeconfig.json")) }
    let(:cluster) { create(:cluster, account:, external_id: "1") }

    before do
      allow(client).to receive(:get_kubernetes_config).and_return(JSON.parse(kubeconfig_json))
    end

    it "fetches kubernetes config from the client, and sets the context" do
      result = portainer_stack.fetch_kubeconfig(cluster)
    end
  end
end
