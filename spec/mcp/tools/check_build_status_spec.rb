# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::CheckBuildStatus do
  it 'returns builds for the project with logs' do
    build = create(:build, status: :completed, digest: "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4")
    build.log_outputs.create!(output: "Build complete")
    user = create(:user)
    create(:account_user, account: build.project.account, user: user)

    response = described_class.call(project_id: build.project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first['commit_sha']).to eq('abc123')
    expect(result.first['logs']).to include('Build complete')
  end
end
