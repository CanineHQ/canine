require 'rails_helper'
require 'support/shared_contexts/with_portainer'

RSpec.describe Portainer::SyncClusters do
  let(:account) { create(:account) }
  let!(:provider) { create(:provider, :portainer, user: account.owner) }
  let!(:stack_manager) { create(:stack_manager, account:) }

  context 'syncs clusters from portainer' do
    include_context 'with portainer'
    it 'can sync clusters from portainer' do
      result = described_class.execute(user: account.owner, account:)
      expect(result).to be_success
      expect(result.clusters.count).to eql(2)
      expect(result.clusters.first.name).to eql('local')
      expect(result.clusters.last.name).to eql('testing-production')
    end
  end
end
