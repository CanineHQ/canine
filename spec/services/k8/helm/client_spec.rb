require 'rails_helper'

RSpec.describe K8::Helm::Client do
  let(:runner) { instance_double(Cli::RunAndReturnOutput) }
  let(:client) { described_class.new(runner) }

  describe '#connected?' do
    it 'returns false when not connected' do
      expect(client).not_to be_connected
    end

    it 'returns false when @kubeconfig is nil' do
      client.instance_variable_set(:@kubeconfig, nil)
      expect(client).not_to be_connected
    end

    it 'returns true when @kubeconfig is present' do
      client.instance_variable_set(:@kubeconfig, { "apiVersion" => "v1" })
      expect(client).to be_connected
    end
  end

  describe '#build_install_command' do
    it 'serializes all options into the helm command' do
      command = client.build_install_command(
        "my-release",
        "/path/to/chart",
        values_file_path: "/tmp/values.yaml",
        namespace: "production",
        timeout: "5m0s",
        dry_run: false,
        atomic: true,
        wait: true,
        history_max: 10
      )

      expect(command).to eq(
        "helm upgrade --install my-release /path/to/chart " \
        "-f /tmp/values.yaml " \
        "--namespace production " \
        "--timeout=5m0s " \
        "--atomic " \
        "--wait " \
        "--history-max=10"
      )
    end

    it 'excludes optional flags when not set' do
      command = client.build_install_command(
        "my-release",
        "/path/to/chart",
        values_file_path: "/tmp/values.yaml",
        namespace: "default",
        timeout: "1000s",
        dry_run: false,
        atomic: false,
        wait: false,
        history_max: nil
      )

      expect(command).to eq(
        "helm upgrade --install my-release /path/to/chart " \
        "-f /tmp/values.yaml " \
        "--namespace default " \
        "--timeout=1000s"
      )
    end
  end
end
