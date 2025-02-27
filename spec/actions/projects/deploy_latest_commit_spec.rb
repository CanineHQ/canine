# spec/actions/projects/create_spec.rb
require 'rails_helper'

class MockCommit < Struct.new(:sha, :commit)
end

class MockGithub
  def commits
    [ MockCommit.new(sha: "1234", commit: { message: "initial commit" }) ]
  end
end

RSpec.describe Projects::DeployLatestCommit do
  let(:project) { create(:project) }
  let(:subject) { described_class.execute(project:) }

  context 'github project' do
    it 'fetches from github and creates a new build' do
      expect(Github::Client).to receive(:new).and_return(MockGithub.new)
      expect(Projects::BuildJob).to receive(:perform_later)

      expect { subject }.to change { project.builds.count }.by(1)
    end
  end
end
