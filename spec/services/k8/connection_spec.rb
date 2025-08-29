require 'rails_helper'
require 'support/shared_contexts/with_portainer'
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

  describe 'using the K8Stack' do
    context 'kubernetes provider is portainer' do
      include_context 'with portainer'
      let!(:cluster) { create(:cluster, kubeconfig: nil) }
      let(:account) { create(:account, owner: user) }

      before do
        create(:provider, provider: 'portainer', access_token: 'jwt', user:)
        create(:stack_manager, account:)
      end

      it 'returns the kubeconfig' do
        expect(connection.kubeconfig).to eq(JSON.parse(File.read(Rails.root.join(*%w[spec resources portainer kubeconfig.json]))))
      end
    end
  end
end
