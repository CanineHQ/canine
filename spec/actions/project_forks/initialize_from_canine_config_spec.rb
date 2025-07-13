require 'rails_helper'

RSpec.describe ProjectForks::InitializeFromCanineConfig do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:) }
  let(:parent_project) { create(:project, account:, cluster:) }
  let(:child_project) { create(:project, account:, cluster:) }
  let(:project_fork) { create(:project_fork, parent_project:, child_project:) }

  describe '#execute' do
    context 'when project fork has canine config' do
      let(:canine_config) do
        {
          'services' => [
            {
              'name' => 'web',
              'container_port' => 6379,
              'service_type' => 'web_service'
            },
            {
              'name' => 'worker',
              'container_port' => 5432,
              'service_type' => 'background_service'
            }
          ],
          'environment_variables' => [
            {
              'name' => 'DATABASE_URL',
              'value' => 'postgres://localhost/test'
            },
            {
              'name' => 'REDIS_URL',
              'value' => 'redis://localhost:6379'
            }
          ]
        }
      end

      before do
        child_project.update!(canine_config:)
      end

      it 'creates services from the config' do
        expect {
          described_class.execute(project_fork:)
        }.to change { child_project.services.count }.by(2)

        services = child_project.services.order(:name)

        expect(services[0].name).to eq('web')
        expect(services[0].container_port).to eq(6379)
        expect(services[0].service_type).to eq('web_service')

        expect(services[1].name).to eq('worker')
        expect(services[1].container_port).to eq(5432)
        expect(services[1].service_type).to eq('background_service')
      end

      it 'creates environment variables from the config' do
        expect {
          described_class.execute(project_fork:)
        }.to change { child_project.environment_variables.count }.by(2)

        env_vars = child_project.environment_variables.order(:name)

        expect(env_vars[0].name).to eq('DATABASE_URL')
        expect(env_vars[0].value).to eq('postgres://localhost/test')

        expect(env_vars[1].name).to eq('REDIS_URL')
        expect(env_vars[1].value).to eq('redis://localhost:6379')
      end

      it 'returns success context' do
        result = described_class.execute(project_fork:)
        expect(result).to be_success
      end
    end

    context 'when project fork has empty canine config' do
      before do
        child_project.update!(canine_config: {})
      end

      it 'skips and returns success' do
        result = described_class.execute(project_fork:)

        expect(result).to be_success
        expect(child_project.services.count).to eq(0)
        expect(child_project.environment_variables.count).to eq(0)
      end
    end

    context 'when project fork has no canine config' do
      before do
        child_project.update!(canine_config: nil)
      end

      it 'skips and returns success' do
        result = described_class.execute(project_fork:)

        expect(result).to be_success
        expect(child_project.services.count).to eq(0)
        expect(child_project.environment_variables.count).to eq(0)
      end
    end
  end
end
