require 'rails_helper'

RSpec.describe Projects::CheckForNewCommitsJob, type: :job do
  describe '#perform' do
    shared_context 'git project setup' do |provider_trait, commit_sha, commit_message|
      let(:project) { create(:project, provider_trait, autodeploy: true, branch: 'main') }

      let(:mock_commit) do
        Git::Common::Commit.new(
          sha: commit_sha,
          message: commit_message,
          author_name: 'Test Author',
          author_email: 'test@example.com',
          authored_at: Time.current,
          committer_name: 'Test Committer',
          committer_email: 'committer@example.com',
          committed_at: Time.current,
          url: "https://example.com/commit/#{commit_sha}"
        )
      end

      let(:mock_client) { double("Git::Client", commits: commits) }
      let(:commits) { [ mock_commit ] }

      before do
        allow(Git::Client).to receive(:from_project).and_return(mock_client)
      end
    end

    shared_examples 'creates a new build' do |commit_sha, commit_message|
      it 'creates a new build for a new commit' do
        expect {
          described_class.new.perform(project)
        }.to change { project.builds.count }.by(1)

        build = project.builds.last
        expect(build.commit_sha).to eq(commit_sha)
        expect(build.commit_message).to eq(commit_message)
      end

      it 'enqueues a BuildJob' do
        expect(Projects::BuildJob).to receive(:perform_later).with(
          an_instance_of(Build),
          nil
        )
        described_class.new.perform(project)
      end

      it 'logs new commit detection' do
        allow(Projects::BuildJob).to receive(:perform_later)
        expect(Rails.logger).to receive(:info).with(
          "New commit detected for project #{project.name}: #{commit_sha}"
        )
        described_class.new.perform(project)
      end
    end

    shared_examples 'prevents duplicate builds' do |commit_sha|
      it 'does not create duplicate builds for the same commit' do
        create(:build, project: project, commit_sha: commit_sha)

        expect {
          described_class.new.perform(project)
        }.not_to change { project.builds.count }
      end
    end

    context 'with GitHub projects' do
      include_context 'git project setup', :github, 'abc123', 'Test commit'

      include_examples 'creates a new build', 'abc123', 'Test commit'
      include_examples 'prevents duplicate builds', 'abc123'

      context 'when no commits are returned' do
        let(:commits) { [] }

        it 'does not create a build' do
          expect {
            described_class.new.perform(project)
          }.not_to change { project.builds.count }
        end
      end
    end

    context 'with GitLab projects' do
      include_context 'git project setup', :gitlab, 'def456', 'GitLab test commit'

      include_examples 'creates a new build', 'def456', 'GitLab test commit'
      include_examples 'prevents duplicate builds', 'def456'
    end

    context 'with non-git projects' do
      let(:non_git_project) { create(:project, :container_registry, autodeploy: true) }

      it 'skips non-git projects' do
        initial_build_count = non_git_project.builds.count
        described_class.new.perform(non_git_project)
        expect(non_git_project.builds.count).to eq(initial_build_count)
      end
    end

    context 'error handling' do
      include_context 'git project setup', :github, 'abc123', 'Test commit'

      before do
        allow(Git::Client).to receive(:from_project).and_raise(StandardError.new('API Error'))
      end

      it 'logs errors and does not raise' do
        expect(Rails.logger).to receive(:error).with(
          "Failed to check for updates on project #{project.id}: API Error"
        )

        expect {
          described_class.new.perform(project)
        }.not_to raise_error
      end
    end

    context 'with commit message that is nil' do
      include_context 'git project setup', :github, 'nil123', nil

      it 'uses fallback commit message' do
        described_class.new.perform(project)

        build = project.builds.last
        expect(build.commit_message).to eq('Auto-detected commit')
      end
    end
  end
end
