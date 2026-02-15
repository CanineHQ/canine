require 'rails_helper'

RSpec.describe AddOns::SetPackageDetails do
  let(:add_on) { build(:add_on) }
  let(:chart_details) { { 'name' => 'test-chart', 'version' => '1.0.0' } }

  before do
    allow(AddOns::FetchChartDetailsFromArtifactHub).to receive(:execute).and_return(
      double(success?: true, failure?: false, response: chart_details)
    )
  end

  it 'fetches package details and saves to add on' do
    result = described_class.execute(add_on:)
    expect(result.add_on.metadata['package_details']).to eq(chart_details)
  end

  context 'when package details fetch fails' do
    before do
      allow(AddOns::FetchChartDetailsFromArtifactHub).to receive(:execute).and_return(
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
