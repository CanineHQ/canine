# spec/actions/projects/create_spec.rb
require 'rails_helper'

class MockGithub
  def commits(branch)
    [
      Git::Common::Commit.new(
        sha: "1234",
        message: "initial commit",
        author_name: "Test Author",
        author_email: "test@example.com",
        authored_at: Time.current,
        committer_name: "Test Committer",
        committer_email: "committer@example.com",
        committed_at: Time.current,
        url: "https://example.com/commit/1234"
      )
    ]
  end
end

RSpec.describe Projects::DeployLatestCommit do
  let(:project) { create(:project) }

  before do
    allow(Git::Client).to receive(:from_project).and_return(MockGithub.new)
  end

  context 'github project' do
    let(:subject) { described_class.execute(project:) }

    it 'fetches from github and creates a new build' do
      expect(Projects::BuildJob).to receive(:perform_later)

      expect { subject }.to change { project.builds.count }.by(1)
    end
  end

  context 'skip_build' do
    let(:subject) { described_class.execute(project:, skip_build: true) }

    it 'starts a deployment and copies digest from current deployment' do
      previous_digest = "sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4"
      previous_build = create(:build, project: project, status: :completed, digest: previous_digest)
      create(:deployment, build: previous_build, status: :completed)
      project.reload

      expect(Projects::DeploymentJob).to receive(:perform_later)
      result = subject

      expect(result.build.digest).to eq(previous_digest)
    end

    it 'fails when no previous deployment with digest exists' do
      result = subject

      expect(result).to be_failure
      expect(result.message).to eq("Cannot skip build: no previous deployment with a valid digest")
      expect(result.build.status).to eq("failed")
    end
  end
end
