# == Schema Information
#
# Table name: clusters
#
#  id              :bigint           not null, primary key
#  cluster_type    :integer          default("k8s")
#  kubeconfig      :jsonb
#  name            :string           not null
#  options         :jsonb            not null
#  skip_tls_verify :boolean          default(FALSE), not null
#  status          :integer          default("initializing"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  external_id     :string
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
  describe 'networking mode metadata' do
    it 'defaults networking_mode to ingress' do
      cluster = build(:cluster, metadata: {})

      expect(cluster).to be_valid
      expect(cluster.networking_mode).to eq('ingress')
      expect(cluster).to be_ingress_based
    end

    it 'supports gateway mode' do
      cluster = build(:cluster, metadata: { "networking_mode" => "gateway" })

      expect(cluster).to be_valid
      expect(cluster).to be_gateway_based
    end

    it 'rejects unknown networking mode' do
      cluster = build(:cluster, metadata: { "networking_mode" => "invalid" })

      expect(cluster).not_to be_valid
      expect(cluster.errors[:metadata]).to include("networking_mode must be one of: ingress, gateway")
    end
  end

  describe '#namespaces' do
    let(:cluster) { create(:cluster) }
    let!(:project) { create(:project, cluster: cluster) }
    let!(:add_on) { create(:add_on, cluster: cluster) }

    it 'returns the reserved namespaces and project/add_on names' do
      expect(cluster.namespaces).to include(project.namespace)
      expect(cluster.namespaces).to include(add_on.namespace)
    end
  end
end
