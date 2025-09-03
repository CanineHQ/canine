require 'rails_helper'

RSpec.describe ProjectForks::ForkProject do
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
    # Mock Git client for all tests to avoid authentication issues
    allow(Git::Client).to receive(:from_project).and_return(git_client)
    allow(git_client).to receive(:get_file).with('.canine.yml', 'feature/test').and_return(nil)
    allow(git_client).to receive(:get_file).with('.canine.yml.erb', 'feature/test').and_return(nil)
  end

  describe '#execute' do
    context 'when successful' do
      let(:result) { described_class.execute(parent_project:, pull_request:) }

      it 'creates a project fork' do
        expect { result }.to change { ProjectFork.count }.by(1)
        expect(result).to be_success
      end

      it 'creates a child project with correct attributes' do
        result
        project_fork = result.project_fork
        child_project = project_fork.child_project

        expect(child_project.name).to eq("#{parent_project.name}-42")
        expect(child_project.branch).to eq("feature/test")
        expect(child_project.cluster_id).to eq(parent_project.project_fork_cluster_id)
      end

      it 'duplicates the project credential provider' do
        expect { result }.to change { ProjectCredentialProvider.count }.by(1)

        child_project = result.project_fork.child_project
        expect(child_project.project_credential_provider).to be_present
        expect(child_project.project_credential_provider.provider).to eq(provider)
      end

      it 'sets project fork attributes correctly' do
        result
        project_fork = result.project_fork

        expect(project_fork.parent_project).to eq(parent_project)
        expect(project_fork.external_id).to eq("123")
        expect(project_fork.number).to eq("42")
        expect(project_fork.title).to eq("Test PR")
        expect(project_fork.url).to eq("https://github.com/test/repo/pull/42")
        expect(project_fork.user).to eq("testuser")
      end

      it 'includes project_fork in the context' do
        expect(result.project_fork).to be_a(ProjectFork)
      end
    end

    context 'with build configuration' do
      let!(:build_configuration) do
        create(:build_configuration,
               project: parent_project,
               driver: :docker)
      end

      it 'duplicates the build configuration for the child project' do
        result = described_class.execute(parent_project:, pull_request:)

        expect(result).to be_success
        child_project = result.project_fork.child_project
        child_build_config = child_project.build_configuration

        expect(child_build_config).to be_present
        expect(child_build_config.driver).to eq(build_configuration.driver)
        expect(child_build_config.project).to eq(child_project)
        expect(child_build_config.id).not_to eq(build_configuration.id)
      end
    end

    context 'without build configuration' do
      let(:provider) { create(:provider, :container_registry, user: account.owner) }
      before do
        parent_project.build_configuration = nil
        parent_project.save!
      end

      it 'does not create a build configuration for the child project' do
        result = described_class.execute(parent_project:, pull_request:)

        expect(result).to be_success
        child_project = result.project_fork.child_project
        expect(child_project.build_configuration).to be_nil
      end
    end

    context 'with canine config file' do
      let(:canine_config_content) do
        Git::Common::File.new(
          '.canine.yml',
          File.read(Rails.root.join('spec', 'resources', 'canine_config', 'example_1.yaml')),
          'feature/test'
        )
      end

      before do
        allow(git_client).to receive(:get_file).with('.canine.yml', 'feature/test').and_return(canine_config_content)
      end

      it 'fetches and stores the canine config' do
        result = described_class.execute(parent_project:, pull_request:)

        expect(result).to be_success
        child_project = result.project_fork.child_project

        expect(child_project.canine_config).to be_present
        expect(child_project.canine_config['services']).to be_an(Array)
        expect(child_project.canine_config['services'].first['name']).to eq('web')
        expect(child_project.canine_config['environment_variables']).to be_an(Array)
        expect(child_project.canine_config['environment_variables'].first['name']).to eq('DATABASE_URL')
        expect(child_project.predeploy_command).to eq('echo "Pre deploy script"')
        expect(child_project.postdeploy_command).to eq('echo "Post deploy script"')
        expect(child_project.predestroy_command).to eq('echo "Pre destroy script"')
        expect(child_project.postdestroy_command).to eq('echo "Post destroy script"')
      end
    end

    context 'without canine config file' do
      # Git client is already mocked in the parent before block

      it 'still creates the project fork successfully' do
        result = described_class.execute(parent_project:, pull_request:)

        expect(result).to be_success
        expect(result.project_fork.child_project.canine_config).to eq({})
      end
    end

    context 'when transaction fails' do
      before do
        allow_any_instance_of(ProjectFork).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'returns failure context' do
        result = described_class.execute(parent_project:, pull_request:)

        expect(result).to be_failure
        expect(result.message).to include("Failed to create project fork")
      end
    end
  end
end
