require 'rails_helper'

RSpec.describe K8::Helm::ChartBuilder do
  let(:chart_name) { 'test-chart' }
  let(:logger) { double('logger', info: nil) }
  let(:mock_client) { instance_double(K8::Helm::Client) }
  let(:chart_builder) { described_class.new(chart_name, logger) }

  let(:mock_resource) do
    double('resource',
      to_yaml: "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: test-config",
      suggested_file_name: 'configmap_test-config.yaml'
    )
  end

  before do
    allow(K8::Helm::Client).to receive(:connect).and_return(mock_client)
    chart_builder.instance_variable_set(:@client, mock_client)
  end

  describe '#install_chart' do
    let(:captured_directory) { {} }

    before do
      allow(mock_client).to receive(:install) do |name, chart_dir, **opts|
        captured_directory[:chart_yaml] = File.read(File.join(chart_dir, 'Chart.yaml'))
        captured_directory[:templates] = Dir.glob(File.join(chart_dir, 'templates', '*')).map do |f|
          { name: File.basename(f), content: File.read(f) }
        end
      end
    end

    it 'creates Chart.yaml with correct structure' do
      chart_builder.install_chart('default')

      yaml = YAML.safe_load(captured_directory[:chart_yaml])
      expect(yaml['apiVersion']).to eq('v2')
      expect(yaml['name']).to eq(chart_name)
      expect(yaml['version']).to eq('1.0.0')
      expect(yaml['type']).to eq('application')
    end

    it 'creates templates directory with resource files' do
      chart_builder << mock_resource

      chart_builder.install_chart('default')

      expect(captured_directory[:templates].length).to eq(1)
      expect(captured_directory[:templates][0][:name]).to eq('configmap_test-config.yaml')
      expect(captured_directory[:templates][0][:content]).to eq(mock_resource.to_yaml)
    end

    it 'writes multiple resources to separate template files' do
      resource1 = double('resource1', to_yaml: "kind: ConfigMap\nmetadata:\n  name: config", suggested_file_name: 'configmap_config.yaml')
      resource2 = double('resource2', to_yaml: "kind: Secret\nmetadata:\n  name: secret", suggested_file_name: 'secret_secret.yaml')

      chart_builder << resource1
      chart_builder << resource2

      chart_builder.install_chart('default')

      filenames = captured_directory[:templates].map { |t| t[:name] }
      expect(filenames).to contain_exactly('configmap_config.yaml', 'secret_secret.yaml')
    end

    it 'calls client.install with correct arguments' do
      expect(mock_client).to receive(:install).with(
        chart_name,
        kind_of(String),
        namespace: 'my-namespace'
      )

      chart_builder.install_chart('my-namespace')
    end
  end
end
