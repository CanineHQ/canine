require 'rails_helper'

RSpec.describe K8::Helm::Client do
  let(:runner) { instance_double(Cli::RunAndReturnOutput) }
  let(:client) { described_class.new(runner) }
  let(:cluster) { create(:cluster) }
  let(:connection) { K8::Connection.new(cluster, nil) }

  describe '#connected?' do
    it 'returns false when not connected' do
      expect(client).not_to be_connected
    end

    it 'returns true when connection kubeconfig is present' do
      client.connect(connection)
      expect(client).to be_connected
    end
  end

  describe '#build_install_command' do
    it 'serializes all options into the helm command' do
      command = client.build_install_command(
        "my-release",
        "/path/to/chart",
        "1.0.0",
        values_file_path: "/tmp/values.yaml",
        namespace: "production",
        timeout: "5m0s",
        dry_run: false,
        atomic: true,
        wait: true,
        history_max: 10,
        create_namespace: true,
        skip_tls_verify: true
      )

      expect(command).to eq(
        "helm upgrade --install my-release /path/to/chart " \
        "-f /tmp/values.yaml " \
        "--namespace production " \
        "--timeout=5m0s " \
        "--version 1.0.0 " \
        "--atomic " \
        "--wait " \
        "--history-max=10 " \
        "--create-namespace " \
        "--kube-insecure-skip-tls-verify"
      )
    end

    it 'excludes optional flags when not set' do
      command = client.build_install_command(
        "my-release",
        "/path/to/chart",
        "1.0.0",
        values_file_path: "/tmp/values.yaml",
        namespace: "default",
        timeout: "1000s",
        dry_run: false,
        atomic: false,
        wait: false,
        history_max: nil,
        create_namespace: false,
        skip_tls_verify: false
      )

      expect(command).to eq(
        "helm upgrade --install my-release /path/to/chart " \
        "-f /tmp/values.yaml " \
        "--namespace default " \
        "--timeout=1000s " \
        "--version 1.0.0"
      )
    end
  end
end
