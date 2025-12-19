require 'rails_helper'

RSpec.describe Clusters::Filter do
  it 'filters clusters by name with case-insensitive ILIKE' do
    account = create(:account)
    prod = create(:cluster, account: account, name: 'production-us')
    create(:cluster, account: account, name: 'staging-eu')

    expect(described_class.execute(params: { q: 'PROD' }, clusters: Cluster.all).clusters).to eq([ prod ])
    expect(described_class.execute(params: { q: '' }, clusters: Cluster.all).clusters.count).to eq(2)
  end
end
