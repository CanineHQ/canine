require 'rails_helper'

RSpec.describe Projects::Update do
  let(:user) { create(:user) }
  let(:provider) { create(:provider, :github, user:) }
  let(:cluster) { create(:cluster) }
  let(:project) do
    create(:project,
      name: 'original-name',
      branch: 'main',
      cluster: cluster,
      repository_url: 'original/repo',
    )
  end

  describe '.call' do
    context 'with valid parameters' do
      let(:params) do
        ActionController::Parameters.new({
          project: {
            name: 'updated-name',
            branch: 'develop',
            cluster_id: cluster.id,
            repository_url: 'updated/repo',
            build_configuration: {
              context_directory: './app',
              dockerfile_path: 'docker/Dockerfile'
            }
          }
        })
      end

      subject { described_class.call(project, params) }

      it 'updates the project successfully' do
        result = subject
        expect(result).to be_success
        expect(result.project.name).to eq('updated-name')
        expect(result.project.branch).to eq('develop')
        expect(result.project.build_configuration.context_directory).to eq('./app')
        expect(result.project.repository_url).to eq('updated/repo')
        expect(result.project.build_configuration.dockerfile_path).to eq('docker/Dockerfile')
      end

      it 'strips and downcases repository_url' do
        params[:project][:repository_url] = '  UPPER/REPO  '
        result = subject
        expect(result).to be_success
        expect(result.project.repository_url).to eq('upper/repo')
      end
    end

    context 'with build_configuration parameters' do
      let(:build_provider) { create(:provider, :container_registry, user:) }
      let(:build_cloud) { create(:build_cloud, cluster: cluster) }
      let(:params) do
        ActionController::Parameters.new({
          project: {
            name: 'updated-name',
            build_configuration: {
              driver: 'k8s',
              build_cloud_id: build_cloud.id,
              provider_id: build_provider.id,
              image_repository: 'updated/repo',
              context_directory: './app',
              dockerfile_path: 'docker/Dockerfile'
            }
          }
        })
      end

      context 'when project has existing build_configuration' do
        let!(:existing_build_config) do
          create(:build_configuration,
            project: project,
            driver: 'docker',
            provider: provider
          )
        end

        subject { described_class.call(project, params) }

        it 'updates the existing build_configuration' do
          result = subject
          expect(result).to be_success
          existing_build_config.reload
          expect(existing_build_config.driver).to eq('k8s')
          expect(existing_build_config.build_cloud_id).to eq(build_cloud.id)
          expect(existing_build_config.provider_id).to eq(build_provider.id)
        end
      end

      context 'when project does not have build_configuration' do
        subject { described_class.call(project, params) }

        it 'creates a new build_configuration' do
          expect { subject }.to change { BuildConfiguration.count }.by(1)
          result = subject
          expect(result).to be_success
          build_config = project.reload.build_configuration
          expect(build_config.driver).to eq('k8s')
          expect(build_config.build_cloud_id).to eq(build_cloud.id)
          expect(build_config.provider_id).to eq(build_provider.id)
        end
      end

      context 'when provider_id is not provided in build_configuration' do
        let(:params) do
          ActionController::Parameters.new({
            project: {
              name: 'updated-name',
              build_configuration: {
                driver: 'k8s',
                build_cloud_id: build_cloud.id,
                image_repository: 'updated/repo'
              }
            }
          })
        end

        subject { described_class.call(project, params) }

        it 'uses provider_id from project_credential_provider' do
          result = subject
          expect(result).to be_success
          build_config = project.reload.build_configuration
          expect(build_config.provider_id).to eq(project.project_credential_provider.provider_id)
        end
      end
    end

    context 'with project_credential_provider_attributes' do
      let(:new_provider) { create(:provider, :github, user:) }
      let(:params) do
        ActionController::Parameters.new({
          project: {
            name: 'updated-name',
            project_credential_provider_attributes: {
              provider_id: new_provider.id
            }
          }
        })
      end

      subject { described_class.call(project, params) }

      it 'updates the project credential provider' do
        original_provider_id = project.project_credential_provider.provider_id
        result = subject
        expect(result).to be_success
        expect(project.project_credential_provider.reload.provider_id).to eq(new_provider.id)
        expect(project.project_credential_provider.provider_id).not_to eq(original_provider_id)
      end
    end

    context 'with invalid parameters' do
      let(:params) do
        ActionController::Parameters.new({
          project: {
            name: nil
          }
        })
      end

      subject { described_class.call(project, params) }

      it 'fails when validation fails' do
        result = subject
        expect(result).to be_failure
        expect(result.message).to include("Name can't be blank")
      end
    end

    context 'when database error occurs' do
      let(:params) do
        ActionController::Parameters.new({
          project: {
            name: 'updated-name'
          }
        })
      end

      subject { described_class.call(project, params) }

      it 'fails with error message' do
        allow_any_instance_of(Project).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(project))
        result = subject
        expect(result).to be_failure
      end
    end

    context 'with transaction rollback' do
      let(:build_cloud) { create(:build_cloud, cluster: cluster) }
      let(:params) do
        ActionController::Parameters.new({
          project: {
            name: 'updated-name',
            build_configuration: {
              driver: 'k8s',
              build_cloud_id: build_cloud.id
            }
          }
        })
      end

      subject { described_class.call(project, params) }

      it 'rolls back all changes if build_configuration save fails' do
        allow_any_instance_of(BuildConfiguration).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(BuildConfiguration.new))

        original_name = project.name
        result = subject

        expect(result).to be_failure
        expect(project.reload.name).to eq(original_name)
      end
    end

    context 'with buildpacks' do
      include_context 'buildpack details stubbing'
      let(:build_provider) { create(:provider, :container_registry, user:) }
      let!(:existing_build_config) do
        create(:build_configuration,
          project: project,
          driver: 'docker',
          provider: build_provider,
          build_type: 'buildpacks',
          buildpack_base_builder: 'paketobuildpacks/builder:full'
        )
      end

      let!(:old_build_pack) do
        create(:build_pack,
          build_configuration: existing_build_config,
          namespace: 'paketo-buildpacks',
          name: 'python',
          version: '1.0.0',
          build_order: 0
        )
      end

      let(:params) do
        ActionController::Parameters.new({
          project: {
            name: 'updated-name',
            build_configuration: {
              build_type: 'buildpacks',
              buildpack_base_builder: 'paketobuildpacks/builder:full',
              build_packs_attributes: [
                {
                  namespace: 'paketo-buildpacks',
                  name: 'ruby',
                  version: '0.47.7',
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

      subject { described_class.call(project, params) }

      it 'updates build packs with correct order and removes old packs' do
        expect { subject }.to change { BuildPack.count }.by(1)

        result = subject
        expect(result).to be_success

        build_packs = project.build_configuration.reload.build_packs
        expect(build_packs.count).to eq(2)
        expect(build_packs.map(&:name)).not_to include('python')
        expect(build_packs.first.name).to eq('ruby')
        expect(build_packs.first.build_order).to eq(0)
        expect(build_packs.second.name).to eq('nodejs')
        expect(build_packs.second.build_order).to eq(1)
      end
    end
  end
end
