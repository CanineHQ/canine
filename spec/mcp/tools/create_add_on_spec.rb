# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::CreateAddOn do
  it 'creates an add-on and queues installation' do
    account = create(:account)
    cluster = create(:cluster, account: account)
    user = create(:user)
    create(:account_user, account: account, user: user)

    allow(Namespaced::ValidateNamespace).to receive(:execute)
    allow(AddOns::InstallJob).to receive(:perform_later)

    response = described_class.call(
      name: 'my-redis',
      chart_url: 'bitnami/redis',
      version: '18.6.1',
      repository_url: 'https://charts.bitnami.com/bitnami',
      cluster_id: cluster.id,
      account_id: account.id,
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('installation started')
    expect(response.content.first[:text]).to include('my-redis')
    expect(AddOn.find_by(name: 'my-redis')).to be_present
    expect(AddOns::InstallJob).to have_received(:perform_later)
  end

  it 'returns error for invalid cluster' do
    user = create(:user)
    account = create(:account)
    create(:account_user, account: account, user: user)

    response = described_class.call(
      name: 'my-redis',
      chart_url: 'bitnami/redis',
      version: '18.6.1',
      repository_url: 'https://charts.bitnami.com/bitnami',
      cluster_id: -1,
      account_id: account.id,
      server_context: { user_id: user.id }
    )

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('Cluster not found')
  end
end
