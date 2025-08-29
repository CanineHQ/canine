require 'rails_helper'
RSpec.describe K8::Connection do
  let!(:user) { create(:user) }
  let(:connection) { described_class.new(cluster, user) }

  describe '#kubeconfig' do
    context 'when the cluster has a kubeconfig' do
      let!(:cluster) { create(:cluster) }
      it 'returns the kubeconfig' do
        expect(connection.kubeconfig).to eq(cluster.kubeconfig)
      end
    end
  end
end
