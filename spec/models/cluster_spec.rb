# == Schema Information
#
# Table name: clusters
#
#  id           :bigint           not null, primary key
#  cluster_type :integer          default("k8s")
#  kubeconfig   :jsonb
#  name         :string           not null
#  status       :integer          default("initializing"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  external_id  :string
#
# Indexes
#
#  index_clusters_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
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
