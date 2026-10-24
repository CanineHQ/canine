require 'rails_helper'

RSpec.describe Providers::SyncRegistrySecretsJob do
  let(:user) { create(:user) }
  let!(:deployed) { create(:project, status: :deployed) }
  let(:provider) { deployed.build_provider }
  let!(:undeployed) { create(:project, status: :creating) }
  let(:kubectl) { instance_double(K8::Kubectl, apply_yaml: true) }

  before do
    undeployed.project_credential_provider.update!(provider:)
    undeployed.build_configuration.update!(provider:)
    create(:project, status: :deployed) # uses a different provider
    allow(K8::Kubectl).to receive(:new).and_return(kubectl)
  end

  it "re-applies the pull secret with the new token only to deployed projects using the provider" do
    allow(Git::Github::Client).to receive(:build_client)
      .and_return(double(user: { login: "test_user" }, scopes: [ "repo", "write:packages" ]))
    result = Providers::Update.call(provider, access_token: "new_token")
    expect(result).to be_success
    expect(provider.reload.access_token).to eq("new_token")

    described_class.perform_now(provider, user)

    expect(kubectl).to have_received(:apply_yaml).once do |yaml|
      secret = YAML.safe_load(yaml)
      expect(secret["metadata"]["namespace"]).to eq(deployed.namespace)
      auths = JSON.parse(Base64.decode64(secret["data"][".dockerconfigjson"]))["auths"]
      expect(Base64.decode64(auths["ghcr.io"]["auth"])).to eq("test_user:new_token")
    end
  end
end
