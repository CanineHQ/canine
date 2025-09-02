require 'rails_helper'
require 'support/shared_contexts/with_portainer'

RSpec.describe K8Stack do
  describe '.fetch_kubeconfig' do
    include_context 'with portainer'
    context 'when the stack manager is portainer' do
      let(:account) { create(:account) }
      let!(:provider) { create(:provider, :portainer, user: account.owner) }
      let!(:stack_manager) { create(:stack_manager, :portainer, account:) }
      let(:cluster) { create(:cluster, account:) }

      subject { described_class.fetch_kubeconfig(cluster, account.owner) }

      it 'fetches the kubeconfig' do
        expect(subject).to eql(JSON.parse(File.read(Rails.root.join(*%w[spec resources portainer kubeconfig.json]))))
      end
    end
  end
end
