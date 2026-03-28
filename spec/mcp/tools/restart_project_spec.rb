# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::RestartProject do
  it 'restarts all running services in a project' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    allow(Projects::Restart).to receive(:execute).and_return(
      double(success?: true)
    )

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })

    expect(response.content.first[:text]).to include('have been restarted')
    expect(Projects::Restart).to have_received(:execute)
  end

  it 'returns error for non-existent project' do
    user = create(:user)
    create(:account_user, user: user)

    response = described_class.call(project_id: -1, server_context: { user_id: user.id })

    expect(response.error?).to be true
  end
end
