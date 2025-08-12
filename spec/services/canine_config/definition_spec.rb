require 'rails_helper'

RSpec.describe CanineConfig::Definition do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:, name: 'test-cluster') }
  let(:base_project) { create(:project, project_fork_cluster_id: cluster.id, account:, name: 'test-project') }
  let(:pull_request) do
    Git::Common::PullRequest.new(
      number: 42,
      title: 'Test PR',
      branch: 'feature/test',
      user: 'testuser'
    )
  end

  describe '.parse' do
    context 'with plain YAML content' do
      let(:yaml_content) do
        <<~YAML
          services:
            - name: "web"
              container_port: 3000
              service_type: "web_service"
              domains:
                - example.com
                - www.example.com
          environment_variables:
            - name: "API_KEY"
              value: "test-key"
        YAML
      end

      it 'parses YAML content and returns a Definition instance' do
        definition = described_class.parse(yaml_content, base_project, pull_request)

        expect(definition).to be_a(CanineConfig::Definition)
        expect(definition.to_hash).to include(
          'services' => [
            {
              'name' => 'web',
              'container_port' => 3000,
              'service_type' => 'web_service',
              'domains' => [ 'example.com', 'www.example.com' ]
            }
          ],
          'environment_variables' => [
            {
              'name' => 'API_KEY',
              'value' => 'test-key'
            }
          ]
        )
      end
    end

    context 'with ERB template content' do
      let(:yaml_content) do
        <<~YAML
          services:
            - name: "<%= project_name %>"
              container_port: 3000
              service_type: "web_service"
          environment_variables:
            - name: "DATABASE_URL"
              value: "redis://redis.<%= cluster_name %>.svc.local/<%= number %>"
            - name: "BRANCH"
              value: "<%= branch_name %>"
            - name: "USER"
              value: "<%= username %>"
        YAML
      end

      it 'interpolates ERB variables with context values' do
        definition = described_class.parse(yaml_content, base_project, pull_request)

        expect(definition.to_hash).to include(
          'services' => [
            {
              'name' => 'test-project-42',
              'container_port' => 3000,
              'service_type' => 'web_service'
            }
          ],
          'environment_variables' => [
            {
              'name' => 'DATABASE_URL',
              'value' => 'redis://redis.test-cluster.svc.local/42'
            },
            {
              'name' => 'BRANCH',
              'value' => 'feature/test'
            },
            {
              'name' => 'USER',
              'value' => 'testuser'
            }
          ]
        )
      end
    end

    context 'with code execution attempts' do
      let(:yaml_content) do
        <<~YAML
          services:
            - name: "<%= system('echo pwned') %>"
              container_port: 3000
          environment_variables:
            - name: "DANGEROUS"
              value: "<%= File.read('/etc/passwd') %>"
            - name: "MATH"
              value: "<%= 1 + 1 %>"
            - name: "METHOD_CALL"
              value: "<%= cluster_name.upcase %>"
        YAML
      end

      it 'does not execute code and preserves invalid placeholders as-is' do
        definition = described_class.parse(yaml_content, base_project, pull_request)

        expect(definition.to_hash).to include(
          'services' => [
            {
              'name' => "<%= system('echo pwned') %>",  # Code not executed
              'container_port' => 3000
            }
          ],
          'environment_variables' => [
            {
              'name' => 'DANGEROUS',
              'value' => "<%= File.read('/etc/passwd') %>"  # File not read
            },
            {
              'name' => 'MATH',
              'value' => '<%= 1 + 1 %>'  # Math not evaluated
            },
            {
              'name' => 'METHOD_CALL',
              'value' => '<%= cluster_name.upcase %>'  # Method not called
            }
          ]
        )
      end
    end

    context 'with missing variables' do
      let(:yaml_content) do
        <<~YAML
          services:
            - name: "<%= nonexistent_variable %>"
              container_port: 3000
        YAML
      end

      it 'preserves placeholders for missing variables' do
        definition = described_class.parse(yaml_content, base_project, pull_request)

        expect(definition.to_hash).to include(
          'services' => [
            {
              'name' => '<%= nonexistent_variable %>',
              'container_port' => 3000
            }
          ]
        )
      end
    end

    context 'with invalid YAML' do
      let(:yaml_content) { "invalid: yaml: content:" }

      it 'raises an error' do
        expect {
          described_class.parse(yaml_content, base_project, pull_request)
        }.to raise_error(Psych::SyntaxError)
      end
    end
  end

  describe '.build_context' do
    it 'returns a hash with all required context variables' do
      context = described_class.build_context(base_project, pull_request)

      expect(context).to eq({
        cluster_id: cluster.id,
        cluster_name: 'test-cluster',
        project_name: 'test-project-42',
        number: 42,
        title: 'Test PR',
        branch_name: 'feature/test',
        username: 'testuser'
      })
    end
  end

  describe '#initialize' do
    let(:definition_hash) do
      {
        'services' => [
          { 'name' => 'web', 'container_port' => 3000 }
        ],
        'environment_variables' => [
          { 'name' => 'API_KEY', 'value' => 'secret' }
        ]
      }
    end

    it 'stores the definition hash' do
      definition = described_class.new(definition_hash)
      expect(definition.definition).to eq(definition_hash)
    end
  end

  describe '#services' do
    let(:definition_hash) do
      {
        'services' => [
          {
            'name' => 'web',
            'container_port' => 3000,
            'service_type' => 'web_service',
            'extra_field' => 'should_be_filtered',
            'domains' => [ 'example.com', 'www.example.com' ]
          },
          {
            'name' => 'worker',
            'container_port' => 4000,
            'service_type' => 'background_service'
          }
        ]
      }
    end
    let(:definition) { described_class.new(definition_hash) }

    before do
      allow(Service).to receive(:permitted_params).and_return(
        { 'name' => 'web', 'container_port' => 3000, 'service_type' => 'web_service' },
        { 'name' => 'worker', 'container_port' => 4000, 'service_type' => 'background_service' }
      )
    end

    it 'returns an array of Service objects' do
      services = definition.services

      expect(services).to be_an(Array)
      expect(services.length).to eq(2)
      expect(services).to all(be_a(Service))
    end

    it 'filters service parameters through Service.permitted_params' do
      expect(Service).to receive(:permitted_params).exactly(2).times
      definition.services
    end
  end

  describe '#environment_variables' do
    let(:definition_hash) do
      {
        'environment_variables' => [
          { 'name' => 'DATABASE_URL', 'value' => 'postgres://localhost/test' },
          { 'name' => 'REDIS_URL', 'value' => 'redis://localhost:6379' },
          { 'name' => 'SECRET_KEY', 'value' => 'abc123' }
        ]
      }
    end
    let(:definition) { described_class.new(definition_hash) }

    it 'returns an array of EnvironmentVariable objects' do
      env_vars = definition.environment_variables

      expect(env_vars).to be_an(Array)
      expect(env_vars.length).to eq(3)
      expect(env_vars).to all(be_a(EnvironmentVariable))
    end

    it 'creates EnvironmentVariable objects with correct attributes' do
      env_vars = definition.environment_variables

      expect(env_vars[0].name).to eq('DATABASE_URL')
      expect(env_vars[0].value).to eq('postgres://localhost/test')

      expect(env_vars[1].name).to eq('REDIS_URL')
      expect(env_vars[1].value).to eq('redis://localhost:6379')

      expect(env_vars[2].name).to eq('SECRET_KEY')
      expect(env_vars[2].value).to eq('abc123')
    end
  end

  describe '#to_hash' do
    let(:definition_hash) do
      {
        'services' => [ { 'name' => 'web' } ],
        'environment_variables' => [ { 'name' => 'KEY', 'value' => 'value' } ],
        'extra_field' => 'extra_value'
      }
    end
    let(:definition) { described_class.new(definition_hash) }

    it 'returns the original definition hash' do
      expect(definition.to_hash).to eq(definition_hash)
    end
  end
end
