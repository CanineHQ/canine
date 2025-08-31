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
end
