# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::CreateProject do
  it 'creates a project with the given parameters' do
    account = create(:account)
    cluster = create(:cluster, account: account)
    user = create(:user)
    create(:account_user, account: account, user: user)
    provider = create(:provider, :github, user: user)

    allow(Projects::ValidateGitRepository).to receive(:execute)
    allow(Namespaced::ValidateNamespace).to receive(:execute)
    allow(Projects::RegisterGitWebhook).to receive(:execute)

    response = described_class.call(
      name: 'my-new-app',
      repository_url: 'myorg/my-app',
      cluster_id: cluster.id,
      provider_id: provider.id,
      account_id: account.id,
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('created successfully')
    expect(Project.find_by(name: 'my-new-app')).to be_present
  end

  it 'returns error for invalid cluster' do
    user = create(:user)
    account = create(:account)
    create(:account_user, account: account, user: user)
    provider = create(:provider, :github, user: user)

    response = described_class.call(
      name: 'my-app',
      repository_url: 'myorg/my-app',
      cluster_id: -1,
      provider_id: provider.id,
      account_id: account.id,
      server_context: { user_id: user.id }
    )

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('Cluster not found')
  end
end
