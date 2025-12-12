require 'rails_helper'

RSpec.describe AddOns::Filter do
  it 'filters add_ons by name with case-insensitive ILIKE' do
    cluster = create(:cluster)
    redis = create(:add_on, cluster: cluster, name: 'redis-cache')
    create(:add_on, cluster: cluster, name: 'postgres-db')

    expect(described_class.execute(params: { q: 'REDIS' }, add_ons: AddOn.all).add_ons).to eq([ redis ])
    expect(described_class.execute(params: { q: '' }, add_ons: AddOn.all).add_ons.count).to eq(2)
  end
end
