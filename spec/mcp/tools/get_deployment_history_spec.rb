# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetDeploymentHistory do
  it 'returns deployment history with commit info' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)
    build = create(:build, project: project, status: :completed, commit_sha: 'abc123', commit_message: 'fix bug', digest: "sha256:#{'a' * 64}")
    create(:deployment, build: build, status: :completed)

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.length).to eq(1)
    expect(result.first['commit_sha']).to eq('abc123')
    expect(result.first['commit_message']).to eq('fix bug')
    expect(result.first['status']).to eq('completed')
  end
end
