# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::CreateCluster do
  let(:valid_kubeconfig_yaml) do
    {
      "apiVersion" => "v1",
      "kind" => "Config",
      "clusters" => [ { "name" => "my-cluster", "cluster" => { "server" => "https://example.com:6443" } } ],
      "contexts" => [ { "name" => "my-cluster", "context" => { "cluster" => "my-cluster", "user" => "admin" } } ],
      "current-context" => "my-cluster",
      "users" => [ { "name" => "admin", "user" => { "token" => "test-token" } } ]
    }.to_yaml
  end

  it 'creates a cluster and queues installation' do
    account = create(:account)
    user = create(:user)
    create(:account_user, account: account, user: user)

    allow(Clusters::ValidateKubeConfig).to receive(:execute)
    allow(Clusters::InstallJob).to receive(:perform_later)

    response = described_class.call(
      name: 'prod-cluster',
      kubeconfig_yaml: valid_kubeconfig_yaml,
      account_id: account.id,
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('created and setup started')
    expect(response.content.first[:text]).to include('prod-cluster')
    expect(Cluster.find_by(name: 'prod-cluster')).to be_present
    expect(Clusters::InstallJob).to have_received(:perform_later)
  end

  it 'returns error for invalid YAML' do
    user = create(:user)
    account = create(:account)
    create(:account_user, account: account, user: user)

    response = described_class.call(
      name: 'bad-cluster',
      kubeconfig_yaml: '{ invalid yaml ::',
      account_id: account.id,
      server_context: { user_id: user.id }
    )

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('Invalid kubeconfig YAML')
  end
end
