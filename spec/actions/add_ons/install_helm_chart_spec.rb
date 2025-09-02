require 'rails_helper'

RSpec.describe AddOns::InstallHelmChart do
  let(:add_on) { create(:add_on) }
  let(:user) { create(:user) }
  let(:connection) { K8::Connection.new(add_on, user) }
  let(:kubectl) { instance_double(K8::Kubectl) }
  let(:helm_client) { instance_double(K8::Helm::Client) }

  before do
    allow(K8::Kubectl).to receive(:new).and_return(kubectl)
    allow(kubectl).to receive(:apply_yaml)
    allow(K8::Helm::Client).to receive(:connect).and_return(helm_client)
    allow(helm_client).to receive(:add_repo)
    allow(helm_client).to receive(:repo_update)
    allow(helm_client).to receive(:install)
  end

  describe '#execute' do
    it 'installs the helm chart successfully' do
      expect(add_on).to receive(:update_install_stage!).exactly(4).times
      expect(add_on).to receive(:installing!)
      expect(add_on).to receive(:installed!)

      described_class.execute(connection:)
    end

    context 'when add_on is already installed' do
      before { add_on.installed! }

      it 'sets status to updating' do
        expect(add_on).to receive(:updating!)
        described_class.execute(connection:)
      end
    end

    context 'when an error occurs' do
      before do
        allow(helm_client).to receive(:install).and_raise(StandardError.new('test error'))
      end

      it 'sets status to failed and records error' do
        expect(add_on).to receive(:failed!)
        expect(add_on).to receive(:error).with('test error')
        expect { described_class.execute(connection:) }.to raise_error(StandardError)
      end
    end
  end

  describe '.get_values' do
    it 'merges values with template variables' do
      add_on.metadata = { 'template' => { 'key' => 'value' } }
      add_on.values = { 'key' => 'different_value', 'key_2' => 'value_2' }
      values = described_class.get_values(add_on)
      expect(values['key']).to eq('value')
      expect(values['key_2']).to eq('value_2')
    end
  end
end
