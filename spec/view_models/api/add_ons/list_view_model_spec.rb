require 'rails_helper'

RSpec.describe Api::AddOns::ListViewModel do
  let(:cluster) { create(:cluster) }
  let(:add_on) { create(:add_on, cluster: cluster) }
  let(:view_model) { described_class.new([ add_on ]) }

  describe "#as_json" do
    subject(:result) { view_model.as_json }

    it "returns expected fields" do
      expect(result.first).to include(
        id: add_on.id,
        name: add_on.name,
        namespace: add_on.namespace,
        chart_url: add_on.chart_url,
        chart_type: add_on.chart_type,
        version: add_on.version,
        status: add_on.status,
        install_stage: add_on.install_stage,
        cluster_id: add_on.cluster_id,
        cluster_name: cluster.name,
        created_at: add_on.created_at,
        updated_at: add_on.updated_at
      )
    end

    it "includes a link_to_view_url" do
      expect(result.first[:link_to_view_url]).to include(add_on.id.to_s)
    end
  end
end
