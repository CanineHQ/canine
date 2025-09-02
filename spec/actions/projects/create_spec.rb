# spec/actions/projects/create_spec.rb
require 'rails_helper'

RSpec.describe Projects::Create do
  let(:user) { create(:user) }
  let(:provider) { create(:provider, :github, user:) }
  let(:cluster) { create(:cluster) }
  let(:params) do
    ActionController::Parameters.new({
      project: {
        name: 'example-repo',
        branch: 'main',
        cluster_id: cluster.id,
        docker_build_context_directory: '.',
        repository_url: 'example/repo',
        docker_command: 'rails s',
        dockerfile_path: 'Dockerfile',
        container_registry_url: '',
        project_credential_provider: {
          provider_id: provider.id
        }
      }
    })
  end

  before do
    allow(Projects::ValidateGitRepository).to receive(:execute)
    allow(Projects::ValidateNamespaceAvailability).to receive(:execute)
    allow(Projects::RegisterGitWebhook).to receive(:execute)
  end

  describe '.call' do
    let(:subject) { described_class.call(params, user) }

    context 'for github' do
      it 'creates a project with project_credential_provider and build configuration' do
        expect(subject).to be_success
        expect(subject.project.build_configuration).to be_persisted
        expect(subject.project.build_configuration.provider_id).to eq(provider.id)
      end

      context 'with a build configuration specification' do
        let(:build_cloud) { create(:build_cloud, cluster: cluster) }
        let(:params) do
          ActionController::Parameters.new({
            project: {
              name: 'example-repo',
              branch: 'main',
              cluster_id: cluster.id,
              docker_build_context_directory: '.',
              repository_url: 'example/repo',
              docker_command: 'rails s',
              dockerfile_path: 'Dockerfile',
              container_registry_url: '',
              project_credential_provider: {
                provider_id: provider.id
              },
              build_configuration: {
                driver: 'k8s',
                build_cloud_id: build_cloud.id,
                image_repository: 'different/repo',
                provider_id: provider.id
              }
            }
          })
        end

        it 'creates build configuration according to params' do
          expect(subject).to be_success
          expect(subject.project.build_configuration).to be_persisted
          expect(subject.project.build_configuration.driver).to eq('k8s')
          expect(subject.project.build_configuration.build_cloud_id).to eq(build_cloud.id)
          expect(subject.project.build_configuration.image_repository).to eq('different/repo')
          expect(subject.project.build_configuration.provider_id).to eq(provider.id)
        end
      end
    end

    context 'for docker hub' do
      let(:provider) { create(:provider, :container_registry, user:) }

      it 'creates a project with project_credential_provider' do
        expect(subject).to be_success
      end
    end
  end

  describe '.create_steps' do
    let(:subject) { described_class.create_steps(provider) }

    context 'in cloud mode' do
      before do
        allow(Rails.application.config).to receive(:local_mode).and_return(false)
      end

      it 'validates with github and registers webhooks' do
        expect(subject).to eq([
          Projects::ValidateGitRepository,
          Projects::ValidateNamespaceAvailability,
          Projects::Save,
          Projects::RegisterGitWebhook
        ])
      end
    end

    context 'in local mode' do
      before do
        allow(Rails.application.config).to receive(:local_mode).and_return(true)
      end

      it 'validates with github and does not register webhooks' do
        expect(subject).to eq([
          Projects::ValidateGitRepository,
          Projects::ValidateNamespaceAvailability,
          Projects::Save
        ])
      end
    end
  end
end
