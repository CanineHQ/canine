require 'rails_helper'

RSpec.describe Clusters::Create do
  let(:kubeconfig_yaml) { File.read(Rails.root.join('spec/resources/k8/kubeconfig.yml')) }
  let(:params) do
    params = ActionController::Parameters.new(
      cluster: {
        name: "test-cluster",
        cluster_type: "k8s",
        kubeconfig_yaml_format: "true",
        kubeconfig: kubeconfig_yaml
      }
    )
  end
  let(:account_user) { create(:account_user) }

  describe '.call' do
    context 'when kubeconfig is valid and cluster can connect' do
      before do
        allow(Clusters::ValidateKubeConfig).to receive(:can_connect?).and_return(true)
      end

      it 'returns a successful context' do
        result = described_class.call(params, account_user)
        expect(result).to be_success
      end
    end
  end
end
