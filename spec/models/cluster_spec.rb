require 'rails_helper'

RSpec.describe Cluster, type: :model do
  describe '#namespaces' do
    let(:cluster) { create(:cluster) }
    let!(:project) { create(:project, cluster: cluster) }
    let!(:add_on) { create(:add_on, cluster: cluster) }

    it 'returns the reserved namespaces and project/add_on names' do
      expect(cluster.namespaces).to include(project.name)
      expect(cluster.namespaces).to include(add_on.name)
    end
  end
end
