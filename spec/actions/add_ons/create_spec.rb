require 'rails_helper'

RSpec.describe AddOns::Create do
  let(:add_on) { build(:add_on) }
  let(:chart_details) { { 'name' => 'test-chart', 'version' => '1.0.0' } }

  before do
    allow(AddOns::HelmChartDetails).to receive(:execute).and_return(
      double(success?: true, failure?: false, response: chart_details)
    )
  end

  describe 'errors' do
    context 'there is a project with the same name in the same cluster' do
      let!(:project) { create(:project, name: add_on.name, cluster: add_on.cluster) }
      it 'raises an error' do
        result = described_class.execute(add_on:)
        expect(result.failure?).to be_truthy
      end
    end
  end

  describe '#execute' do
    it 'applies template and fetches package details' do
      expect(add_on).to receive(:save)
      result = described_class.execute(add_on:)
      expect(result.add_on.metadata['package_details']).to eq(chart_details)
    end

    context 'when package details fetch fails' do
      before do
        allow(AddOns::HelmChartDetails).to receive(:execute).and_return(
          double(success?: false, failure?: true)
        )
      end

      it 'adds error and returns' do
        result = described_class.execute(add_on:)
        expect(result.failure?).to be_truthy
        expect(result.add_on.errors[:base]).to include('Failed to fetch package details')
      end
    end
  end

  describe '.apply_template_to_values' do
    let(:template) do
      {
        'master.persistence.size' => { 'type' => 'size', 'value' => '10', 'unit' => 'Gi' },
        'replica.replicaCount' => '5'
      }
    end

    before do
      add_on.metadata['template'] = template
      add_on.chart_type = "redis"
    end

    it 'applies template values correctly' do
      described_class.apply_template_to_values(add_on)
      expect(add_on.values['master']['persistence']['size']).to eq('10Gi')
      expect(add_on.values['replica']['replicaCount']).to eq(5)
    end
  end
end
