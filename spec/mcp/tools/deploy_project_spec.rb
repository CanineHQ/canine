# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::DeployProject do
  it 'starts a deployment for the project' do
    account = create(:account)
    user = create(:user)
    create(:account_user, account:, user:)
    cluster = create(:cluster, account:)
    project = create(:project, cluster:, account:)

    allow(Git::Client).to receive(:from_project).and_return(
      double(commits: [ Git::Common::Commit.new(
        sha: "abc123", message: "test", author_name: "Test", author_email: "test@test.com",
        authored_at: Time.current, committer_name: "Test", committer_email: "test@test.com",
        committed_at: Time.current, url: "http://example.com"
      ) ])
    )
    allow(Projects::BuildJob).to receive(:perform_later)

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })

    expect(response.content.first[:text]).to include('Deployment started')
  end
end
