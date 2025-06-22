# spec/actions/projects/create_spec.rb
require 'rails_helper'

class MockCommit < Struct.new(:sha, :commit)
end

class MockGithub
  def commits(branch)
    [ MockCommit.new(sha: "1234", commit: { message: "initial commit" }) ]
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

    it 'starts a deployment' do
      expect(Projects::DeploymentJob).to receive(:perform_later)

      expect { subject }.to change { project.deployments.count }.by(1)
    end
  end
end
