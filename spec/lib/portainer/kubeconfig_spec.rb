require 'rails_helper'
require 'support/shared_contexts/with_portainer'

RSpec.describe Portainer::Kubeconfig do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:) }
  let!(:provider) { create(:provider, :portainer, user: account.owner) }
  let!(:stack_manager) { create(:stack_manager, account:) }

  context 'gets kubeconfig from portainer' do
    include_context 'with portainer'
    it 'can get kubeconfig from portainer' do
      result = described_class.execute(cluster:, user: account.owner)
      expect(result).to be_success
      expect(result.kubeconfig).to eql(JSON.parse(File.read(Rails.root.join(*%w[spec resources portainer kubeconfig.json]))))
    end
  end
end
