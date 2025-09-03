require 'rails_helper'

RSpec.describe Clusters::Create do
  let(:valid_kubeconfig) do
    YAML.safe_load(File.read(Rails.root.join('spec/resources/k8/kubeconfig.yml')))
  end
  let(:cluster) { build(:cluster, kubeconfig: valid_kubeconfig) }
  let(:user) { create(:user) }

  describe '.call' do
    context 'when kubeconfig is valid and cluster can connect' do
      before do
        allow(Clusters::ValidateKubeConfig).to receive(:can_connect?).and_return(true)
      end

      it 'returns a successful context' do
        result = described_class.call(cluster, user)
        expect(result).to be_success
      end
    end
  end
end
