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
      docker_build_context_directory: '.',
      repository_url: 'original/repo',
      docker_command: 'rails s',
      dockerfile_path: 'Dockerfile',
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
            docker_build_context_directory: './app',
            repository_url: 'updated/repo',
            docker_command: 'bundle exec rails s',
            dockerfile_path: 'docker/Dockerfile'
          }
        })
      end

      subject { described_class.call(project, params) }

      it 'updates the project successfully' do
        result = subject
        expect(result).to be_success
        expect(result.project.name).to eq('updated-name')
        expect(result.project.branch).to eq('develop')
        expect(result.project.docker_build_context_directory).to eq('./app')
        expect(result.project.repository_url).to eq('updated/repo')
        expect(result.project.docker_command).to eq('bundle exec rails s')
        expect(result.project.dockerfile_path).to eq('docker/Dockerfile')
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
              image_repository: 'updated/repo'
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
  end
end
