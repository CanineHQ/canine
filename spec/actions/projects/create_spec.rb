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
    allow(Namespaced::ValidateNamespace).to receive(:execute)
    allow(Projects::RegisterGitWebhook).to receive(:execute)
  end

  describe '.call' do
    let(:subject) { described_class.call(params, user) }

    context 'for github' do
      it 'creates a project with project_credential_provider and build configuration' do
        expect(subject).to be_success
        expect(subject.project.build_configuration).to be_persisted
        expect(subject.project.build_configuration.provider_id).to eq(provider.id)
        expect(subject.project.deployment_configuration).to be_persisted
        expect(subject.project.deployment_configuration.deployment_method).to eq('helm')
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

      context 'with buildpacks' do
        include_context 'buildpack details stubbing'
        let(:params) do
          ActionController::Parameters.new({
            project: {
              name: 'example-repo',
              branch: 'main',
              cluster_id: cluster.id,
              repository_url: 'example/repo',
              docker_command: 'rails s',
              container_registry_url: '',
              project_credential_provider: {
                provider_id: provider.id
              },
              build_configuration: {
                driver: 'docker',
                image_repository: 'example/repo',
                provider_id: provider.id,
                build_type: 'buildpacks',
                buildpack_base_builder: 'paketobuildpacks/builder:full',
                build_packs_attributes: [
                  {
                    namespace: 'paketo-buildpacks',
                    name: 'ruby',
                    version: '',
                    reference_type: 'registry'
                  },
                  {
                    namespace: 'paketo-buildpacks',
                    name: 'nodejs',
                    version: '1.2.3',
                    reference_type: 'registry'
                  }
                ]
              }
            }
          })
        end

        it 'creates build packs associated with build configuration' do
          expect(subject).to be_success
          expect(subject.project.build_configuration).to be_persisted
          expect(subject.project.build_configuration.build_type).to eq('buildpacks')
          expect(subject.project.build_configuration.buildpack_base_builder).to eq('paketobuildpacks/builder:full')

          build_packs = subject.project.build_configuration.build_packs
          expect(build_packs.count).to eq(2)

          first_pack = build_packs.first
          expect(first_pack.namespace).to eq('paketo-buildpacks')
          expect(first_pack.name).to eq('ruby')
          expect(first_pack.version).to eq('')
          expect(first_pack.reference_type).to eq('registry')

          second_pack = build_packs.second
          expect(second_pack.namespace).to eq('paketo-buildpacks')
          expect(second_pack.name).to eq('nodejs')
          expect(second_pack.version).to eq('1.2.3')
          expect(second_pack.reference_type).to eq('registry')
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
        allow(Rails.application.config).to receive(:cloud_mode).and_return(true)
      end

      it 'validates with github and registers webhooks' do
        expect(subject).to eq([
          Projects::ValidateGitRepository,
          Projects::Create::ToNamespaced,
          Projects::BuildDeploymentConfiguration,
          Namespaced::SetUpNamespace,
          Namespaced::ValidateNamespace,
          Projects::InitializeBuildPacks,
          Projects::Save,
          Projects::RegisterGitWebhook
        ])
      end
    end

    context 'in local mode' do
      before do
        allow(Rails.application.config).to receive(:cloud_mode).and_return(false)
      end

      it 'validates with github and does not register webhooks' do
        expect(subject).to eq([
          Projects::ValidateGitRepository,
          Projects::Create::ToNamespaced,
          Projects::BuildDeploymentConfiguration,
          Namespaced::SetUpNamespace,
          Namespaced::ValidateNamespace,
          Projects::InitializeBuildPacks,
          Projects::Save
        ])
      end
    end
  end
end
