require 'rails_helper'

RSpec.describe AddOns::SetPackageDetails do
  let(:add_on) { build(:add_on, chart_url: 'custom/mychart', artifact_hub_package_id: 'helm/custom/mychart', metadata: {}) }
  let(:chart_details) do
    {
      'name' => 'mychart',
      'version' => '1.0.0',
      'logo' => 'https://example.com/logo.png',
      'display_name' => 'My Custom Chart',
      'description' => 'A custom chart'
    }
  end

  before do
    allow(AddOns::FetchChartDetailsFromArtifactHub).to receive(:execute).and_return(
      double(success?: true, failure?: false, response: chart_details)
    )
  end

  it 'fetches package details and extracts display fields' do
    result = described_class.execute(add_on:)
    expect(result.add_on.metadata['logo']).to eq('https://example.com/logo.png')
    expect(result.add_on.metadata['display_name']).to eq('My Custom Chart')
    expect(result.add_on.metadata['description']).to eq('A custom chart')
    expect(result.add_on.version).to eq('1.0.0')
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
      expect(result.add_on.errors[:base]).to include('Failed to fetch package details from Artifact Hub')
    end
  end

  describe '.pluck_styles' do
    let(:add_on) { build(:add_on, chart_url: 'bitnami/redis', metadata: {}) }

    context 'with curated chart definition' do
      before do
        allow(add_on).to receive(:chart_definition).and_return({
          'logo' => '/images/helm/redis.webp',
          'display_name' => 'Redis',
          'description' => 'In-memory database'
        })
      end

      it 'sets metadata from chart definition' do
        described_class.pluck_styles(add_on)

        expect(add_on.metadata['logo']).to eq('/images/helm/redis.webp')
        expect(add_on.metadata['display_name']).to eq('Redis')
        expect(add_on.metadata['description']).to eq('In-memory database')
      end
    end

    context 'with artifact hub response' do
      let(:artifact_hub_response) do
        {
          'logo' => 'https://example.com/logo.png',
          'display_name' => 'Custom Chart',
          'description' => 'Custom description'
        }
      end

      before do
        allow(add_on).to receive(:chart_definition).and_return(nil)
      end

      it 'sets metadata from artifact hub response' do
        described_class.pluck_styles(add_on, artifact_hub_response)

        expect(add_on.metadata['logo']).to eq('https://example.com/logo.png')
        expect(add_on.metadata['display_name']).to eq('Custom Chart')
        expect(add_on.metadata['description']).to eq('Custom description')
      end
    end

    context 'with custom repository (no chart definition or artifact hub)' do
      before do
        allow(add_on).to receive(:chart_definition).and_return(nil)
      end

      it 'sets minimal metadata using chart name' do
        described_class.pluck_styles(add_on)

        expect(add_on.metadata['logo']).to be_nil
        expect(add_on.metadata['display_name']).to eq('redis')
      end
    end
  end
end
