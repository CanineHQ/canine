require 'rails_helper'

RSpec.describe AddOns::Create do
  let(:cluster) { create(:cluster) }
  let(:add_on) { build(:add_on) }
  let(:chart_details) { { 'name' => 'redis', 'version' => '1.0.0' } }

  before do
    allow(Namespaced::ValidateNamespace).to receive(:execute)
    allow(AddOns::FetchChartDetailsFromArtifactHub).to receive(:execute).and_return(
      double(success?: true, failure?: false, response: chart_details)
    )
  end

  describe 'errors' do
    context 'there is a project with the same name in the same cluster' do
      let!(:project) { create(:project, name: add_on.name, cluster: add_on.cluster, namespace: 'taken') }
      let(:add_on) { build(:add_on, namespace: 'taken') }

      it 'raises an error' do
        result = described_class.call(add_on, cluster.account.owner)
        expect(result.failure?).to be_truthy
      end
    end
  end

  let(:params) do
    ActionController::Parameters.new({
      add_on: {
        name: 'redis-main',
        chart_type: 'redis',
        chart_url: 'bitnami/redis',
        repository_url: 'https://charts.bitnami.com/bitnami',
        version: '7.2.3',
        cluster_id: cluster.id,
        metadata: {
          redis: {
            template: {
              'replica.replicaCount' => 3,
              'master.persistence.size' => {
                'type' => 'size',
                'value' => '2',
                'unit' => 'Gi'
              }
            }
          }
        }
      }
    })
  end

  it 'can create an add on successfully' do
    add_on = AddOn.new(AddOns::Create.parse_params(params))
    result = described_class.call(add_on, cluster.account.owner)
    expect(result.success?).to be_truthy
  end
end
