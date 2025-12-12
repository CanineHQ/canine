require 'rails_helper'

RSpec.describe Projects::Filter do
  it 'filters projects by name with case-insensitive ILIKE' do
    cluster = create(:cluster)
    api = create(:project, cluster: cluster, account: cluster.account, name: 'api-service')
    create(:project, cluster: cluster, account: cluster.account, name: 'web-frontend')

    expect(described_class.execute(params: { q: 'API' }, projects: Project.all).projects).to eq([api])
    expect(described_class.execute(params: { q: '' }, projects: Project.all).projects.count).to eq(2)
  end
end
