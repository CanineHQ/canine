# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::RollbackDeployment do
  it 'creates a new deployment from a previous build' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)
    build = create(:build, project: project, status: :completed, commit_sha: 'abc123', digest: "sha256:#{'a' * 64}")

    allow(Projects::DeploymentJob).to receive(:perform_later)

    response = described_class.call(
      project_id: project.id,
      build_id: build.id,
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('Rollback started')
    expect(response.content.first[:text]).to include('abc123')
    expect(Projects::DeploymentJob).to have_received(:perform_later)
  end

  it 'rejects rollback to a failed build' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)
    build = create(:build, project: project, status: :failed)

    response = described_class.call(
      project_id: project.id,
      build_id: build.id,
      server_context: { user_id: user.id }
    )

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('Build not found')
  end
end
