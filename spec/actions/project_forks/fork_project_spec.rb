require 'rails_helper'

RSpec.describe ProjectForks::CreateDefinition do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:) }
  let(:parent_project) { create(:project, account:, cluster:, project_fork_cluster_id: cluster.id) }
  let(:provider) { create(:provider, :github, user: account.owner) }
  let!(:project_credential_provider) { create(:project_credential_provider, project: parent_project, provider:) }
  let(:pull_request) do
    Git::Common::PullRequest.new(
      id: "123",
      title: "Test PR",
      number: "42",
      branch: "feature/test",
      user: "testuser",
      url: "https://github.com/test/repo/pull/42"
    )
  end
  let(:git_client) { instance_double(Git::Github::Client) }

  before do
    allow(Git::Client).to receive(:from_project).and_return(git_client)
    allow(git_client).to receive(:get_file).with('.canine.yml', 'feature/test').and_return(nil)
    allow(git_client).to receive(:get_file).with('.canine.yml.erb', 'feature/test').and_return(nil)
  end

  describe '#execute' do
    it 'creates a definition with parent infra and fork-specific overrides' do
      result = described_class.execute(parent_project:, pull_request:)

      expect(result).to be_success
      definition = result.definition
      expect(definition["project"]["name"]).to eq("#{parent_project.name}-42")
      expect(definition["project"]["branch"]).to eq("feature/test")
      expect(definition["project"]["repository_url"]).to eq(parent_project.repository_url)
      expect(definition["credential_provider"]["provider_id"]).to eq(provider.id)
    end

    it 'clears child records when no .canine.yml exists' do
      result = described_class.execute(parent_project:, pull_request:)

      definition = result.definition
      expect(definition["services"]).to eq([])
      expect(definition["environment_variables"]).to eq([])
      expect(definition["volumes"]).to eq([])
      expect(definition["notifiers"]).to eq([])
      expect(definition["scripts"]).to be_nil
    end

    context 'with .canine.yml' do
      before do
        allow(git_client).to receive(:get_file).with('.canine.yml', 'feature/test').and_return(
          Git::Common::File.new(
            '.canine.yml',
            File.read(Rails.root.join('spec', 'resources', 'canine_config', 'example_1.yaml')),
            'feature/test'
          )
        )
      end

      it 'uses .canine.yml for child records and scripts' do
        result = described_class.execute(parent_project:, pull_request:)

        definition = result.definition
        expect(definition["services"].first["name"]).to eq("web")
        expect(definition["environment_variables"].first["name"]).to eq("DATABASE_URL")
        expect(definition["scripts"]["predeploy"]).to eq('echo "Pre deploy script"')
      end

      it 'preserves parent infra in the definition' do
        result = described_class.execute(parent_project:, pull_request:)

        definition = result.definition
        expect(definition["credential_provider"]["provider_id"]).to eq(provider.id)
        expect(definition["project"]["repository_url"]).to eq(parent_project.repository_url)
      end
    end
  end
end
