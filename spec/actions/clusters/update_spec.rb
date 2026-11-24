require 'rails_helper'

RSpec.describe Clusters::Update do
  let(:cluster) { create(:cluster) }
  let(:user) { create(:user) }
  let(:new_kubeconfig) { cluster.kubeconfig.merge("kind" => "Config", "users" => [ { "name" => "test-user", "user" => { "token" => "rotated" } } ]) }
  let(:credentials) { { server_url: "https://example.com", certificate_authority_data: nil, service_account_token: "manager" } }

  def params(attributes)
    ActionController::Parameters.new(cluster: attributes)
  end

  it 'leaves the credentials alone when no kubeconfig is imported' do
    expect(K8::ManagerServiceAccount).not_to receive(:new)
    expect(described_class.call(cluster, params(name: "renamed", kubeconfig_yaml_format: "true", kubeconfig: ""), user)).to be_success
    expect(cluster.reload).to have_attributes(name: "renamed", kubeconfig: be_present)
  end

  it 'validates an imported kubeconfig and replaces the stored credentials with the service account' do
    allow(Clusters::ValidateKubeConfig).to receive(:can_connect?).and_return(true)
    allow_any_instance_of(K8::ManagerServiceAccount).to receive(:install!).and_return(credentials)
    allow(K8::ManagerServiceAccount).to receive(:full_access?).and_return(true)
    result = described_class.call(cluster, params(kubeconfig_yaml_format: "true", kubeconfig: new_kubeconfig.to_yaml), user)
    expect(result).to be_success, result.message
    expect(cluster.reload).to have_attributes(kubeconfig: nil, **credentials)

    # Importing again issues a new account and retires the one it replaces.
    first_name = cluster.service_account_name
    expect_any_instance_of(K8::ManagerServiceAccount).to receive(:uninstall!) { |account| expect(account.service_account_name).to eq(first_name) }
    expect(described_class.call(cluster, params(kubeconfig_yaml_format: "true", kubeconfig: new_kubeconfig.to_yaml), user)).to be_success
    expect(cluster.reload.service_account_name).not_to eq(first_name)

    allow(Clusters::ValidateKubeConfig).to receive(:can_connect?).and_return(false)
    expect(described_class.call(cluster, params(kubeconfig_yaml_format: "true", kubeconfig: new_kubeconfig.to_yaml), user)).to be_failure
    expect(cluster.reload).to have_attributes(kubeconfig: nil, **credentials)
  end
end
