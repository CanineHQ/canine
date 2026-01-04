# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::CheckBuildStatus do
  it 'returns builds for the project with logs' do
    account = create(:account)
    user = create(:user)
    create(:account_user, account:, user:)
    cluster = create(:cluster, account:)
    project = create(:project, cluster:, account:)
    build = create(:build, project:, status: :completed, commit_sha: 'abc123')
    build.log_outputs.create!(output: "Build complete")

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first['commit_sha']).to eq('abc123')
    expect(result.first['logs']).to include('Build complete')
  end
end
