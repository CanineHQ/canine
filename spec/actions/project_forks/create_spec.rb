require 'rails_helper'

RSpec.describe ProjectForks::Create do
  let(:account) { create(:account) }
  let(:fork_cluster) { create(:cluster, account:) }
  let(:parent_project) { create(:project, project_fork_cluster_id: fork_cluster.id, account:) }
  let(:provider) { create(:provider, :github, user: account.owner) }
  let!(:project_credential_provider) { create(:project_credential_provider, project: parent_project, provider:) }
  let(:pull_request) do
    Git::Common::PullRequest.new(
      id: "1",
      title: "Fake title",
      number: "7301",
      branch: "feature/test",
      user: "testuser",
      url: "https://github.com/test/repo/pull/7301"
    )
  end
  let(:git_client) { instance_double(Git::Github::Client) }

  context 'with a simple yaml file' do
    before do
      allow(Git::Client).to receive(:from_project).and_return(git_client)
      allow(git_client).to receive(:get_file).with('.canine.yml', 'feature/test').and_return(
        Git::Common::File.new(
          '.canine.yml',
          File.read(Rails.root.join('spec', 'resources', 'canine_config', 'example_1.yaml')),
          'feature/test'
        )
      )
    end

    it 'creates a project fork with services and env vars from .canine.yml' do
      result = described_class.call(parent_project:, pull_request:)

      expect(result).to be_success
      expect(result.project_fork).to be_persisted
      expect(result.project.services.count).to eq(1)
      expect(result.project.environment_variables.count).to eq(1)
      expect(result.project.predeploy_command).to eq('echo "Pre deploy script"')
    end
  end

  context 'with a yaml file with erb' do
    before do
      allow(Git::Client).to receive(:from_project).and_return(git_client)
      allow(git_client).to receive(:get_file).with('.canine.yml', 'feature/test').and_return(
        Git::Common::File.new(
          '.canine.yml',
          File.read(Rails.root.join('spec', 'resources', 'canine_config', 'example_2.yaml.erb')),
          'feature/test'
        )
      )
    end

    it 'creates a project fork with interpolated values' do
      result = described_class.call(parent_project:, pull_request:)

      expect(result).to be_success
      expect(result.project_fork).to be_persisted
      expect(result.project.services.count).to eq(1)
    end
  end

  context 'without a canine config file' do
    before do
      allow(Git::Client).to receive(:from_project).and_return(git_client)
      allow(git_client).to receive(:get_file).with('.canine.yml', 'feature/test').and_return(nil)
      allow(git_client).to receive(:get_file).with('.canine.yml.erb', 'feature/test').and_return(nil)
    end

    it 'creates a project fork with no child records' do
      result = described_class.call(parent_project:, pull_request:)

      expect(result).to be_success
      expect(result.project_fork).to be_persisted
      expect(result.project.services.count).to eq(0)
      expect(result.project.environment_variables.count).to eq(0)
    end
  end
end
