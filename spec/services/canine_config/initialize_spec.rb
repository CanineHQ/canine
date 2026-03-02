require 'rails_helper'

RSpec.describe CanineConfig::Initialize do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:) }
  let(:project) { create(:project, account:, cluster:) }

  describe '#execute' do
    context 'when project has canine config' do
      let(:canine_config) do
        {
          'services' => [
            { 'name' => 'web', 'container_port' => 6379, 'service_type' => 'web_service' },
            { 'name' => 'worker', 'container_port' => 5432, 'service_type' => 'background_service' }
          ],
          'environment_variables' => [
            { 'name' => 'DATABASE_URL', 'value' => 'postgres://localhost/test' },
            { 'name' => 'REDIS_URL', 'value' => 'redis://localhost:6379' }
          ]
        }
      end

      before { project.update!(canine_config:) }

      it 'creates services and environment variables from the config' do
        result = described_class.execute(project:)

        expect(result).to be_success
        expect(project.services.count).to eq(2)
        expect(project.environment_variables.count).to eq(2)

        services = project.services.order(:name)
        expect(services[0].name).to eq('web')
        expect(services[1].name).to eq('worker')
      end
    end

    context 'when project has empty canine config' do
      before { project.update!(canine_config: {}) }

      it 'skips and returns success' do
        result = described_class.execute(project:)

        expect(result).to be_success
        expect(project.services.count).to eq(0)
        expect(project.environment_variables.count).to eq(0)
      end
    end

    context 'when project has no canine config' do
      before { project.update!(canine_config: nil) }

      it 'skips and returns success' do
        result = described_class.execute(project:)

        expect(result).to be_success
        expect(project.services.count).to eq(0)
        expect(project.environment_variables.count).to eq(0)
      end
    end
  end
end
