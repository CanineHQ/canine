require 'rails_helper'

RSpec.describe CanineConfig::Definition do
  let(:yaml_path) { Rails.root.join('resources', 'canine_config', 'example_1.yaml.erb') }
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:) }
  let(:base_project) { create(:project, project_fork_cluster_id: cluster.id, account:) }
  let(:pull_request) do
    Git::Common::PullRequest.new(
      number: 42,
      title: 'Test PR',
      branch: 'feature/test',
      user: 'testuser'
    )
  end

  subject(:definition) { described_class.new(yaml_path, base_project, pull_request) }

  describe '#environment_variables' do
    it 'returns environment variables from the definition' do
      env_vars = definition.environment_variables

      expect(env_vars.count).to eq(1)
      expect(env_vars.first.name).to eq('DATABASE_URL')
      expect(env_vars.first.value).to eq('redis://redis.cluster.svc.local/42')
    end
  end

  describe '#services' do
    it 'returns services from the definition' do
      services = definition.services

      expect(services.count).to eq(1)
      expect(services.first.name).to eq('service_1')
      expect(services.first.container_port).to eq(8080)
    end
  end
end
