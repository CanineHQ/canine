require 'rails_helper'

RSpec.describe Clusters::ValidateKubeConfig do
  let(:valid_kubeconfig) do
    YAML.safe_load(File.read(Rails.root.join('spec/resources/k8/kubeconfig.yml')))
  end
  let(:cluster) { create(:cluster, kubeconfig: valid_kubeconfig) }
  let(:user) { create(:user) }

  describe '.valid_kubeconfig_structure?' do
    let(:subject) { described_class.valid_kubeconfig_structure?(valid_kubeconfig) }

    it 'returns valid: true for a valid kubeconfig' do
      expect(subject[:valid]).to be true
    end

    it 'returns valid: false with error for missing apiVersion' do
      valid_kubeconfig.delete("apiVersion")

      expect(subject[:valid]).to be false
      expect(subject[:error]).to include("missing required keys")
      expect(subject[:error]).to include("apiVersion")
    end

    it 'returns valid: false with error for missing kind' do
      valid_kubeconfig.delete("kind")

      expect(subject[:valid]).to be false
      expect(subject[:error]).to include("missing required keys")
      expect(subject[:error]).to include("kind")
    end

    it 'returns valid: false with error for missing clusters' do
      valid_kubeconfig.delete("clusters")

      expect(subject[:valid]).to be false
      expect(subject[:error]).to include("missing required keys")
      expect(subject[:error]).to include("clusters")
    end

    it 'returns valid: false with error for missing contexts' do
      valid_kubeconfig.delete("contexts")

      expect(subject[:valid]).to be false
      expect(subject[:error]).to include("missing required keys")
      expect(subject[:error]).to include("contexts")
    end

    it 'returns valid: false with error for missing current-context' do
      valid_kubeconfig.delete("current-context")

      expect(subject[:valid]).to be false
      expect(subject[:error]).to include("missing required keys")
      expect(subject[:error]).to include("current-context")
    end

    it 'returns valid: false with error for missing users' do
      valid_kubeconfig.delete("users")

      expect(subject[:valid]).to be false
      expect(subject[:error]).to include("missing required keys")
      expect(subject[:error]).to include("users")
    end

    it 'returns valid: false with error for invalid hash' do
      expect(described_class.valid_kubeconfig_structure?("invalid JSON")[:valid]).to be false
    end
  end

  describe '.executed' do
    context 'when can connect' do
      before do
        allow(described_class).to receive(:can_connect?).and_return(true)
      end

      it 'returns true when connection is successful' do
        expect(described_class.execute(cluster:, user:)).to be_success
      end
    end

    context 'when cannot connect' do
      before do
        allow(described_class).to receive(:can_connect?).and_return(false)
      end

      it 'returns false when connection fails' do
        expect(described_class.execute(cluster:, user:)).to be_failure
      end
    end
  end
end
