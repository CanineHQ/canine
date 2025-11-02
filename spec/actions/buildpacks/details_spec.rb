require 'rails_helper'

RSpec.describe Buildpacks::Details do
  describe '.execute' do
    let(:namespace) { 'paketo-buildpacks' }
    let(:name) { 'passenger' }
    let(:fixture_path) { Rails.root.join('spec/resources/build_packs/details_passenger.json') }
    let(:fixture_response) { File.read(fixture_path) }

    before do
      stub_request(:get, "https://registry.buildpacks.io/api/v1/buildpacks/#{namespace}/#{name}")
        .to_return(status: 200, body: fixture_response, headers: { 'Content-Type' => 'application/json' })
    end

    context 'when the API request is successful' do
      it 'returns success' do
        result = described_class.execute(namespace: namespace, name: name)

        expect(result).to be_success
      end

      it 'returns a BuildpackDetailsResult struct' do
        result = described_class.execute(namespace: namespace, name: name)

        expect(result.result).to be_a(Buildpacks::Details::BuildpackDetailsResult)
      end

      it 'parses the latest buildpack information correctly' do
        result = described_class.execute(namespace: namespace, name: name)
        latest = result.result.latest

        expect(latest).to be_a(Buildpacks::Details::BuildpackLatestDetails)
        expect(latest.namespace).to eq('paketo-buildpacks')
        expect(latest.name).to eq('passenger')
        expect(latest.version).to be_present
        expect(latest.description).to include('passenger')
        expect(latest.homepage).to be_present
        expect(latest.licenses).to include('Apache-2.0')
        expect(latest.stacks).to be_an(Array)
        expect(latest.id).to be_present
      end

      it 'parses the versions array correctly' do
        result = described_class.execute(namespace: namespace, name: name)
        versions = result.result.versions

        expect(versions).to be_an(Array)
        expect(versions.first).to be_a(Buildpacks::Details::BuildpackVersion)
        expect(versions.first.version).to be_present
        expect(versions.first.link).to be_present
      end

      it 'versions array contains multiple versions' do
        result = described_class.execute(namespace: namespace, name: name)

        expect(result.result.versions.length).to be > 1
      end
    end

    context 'when the API request fails' do
      before do
        stub_request(:get, "https://registry.buildpacks.io/api/v1/buildpacks/#{namespace}/#{name}")
          .to_return(status: 404, body: 'Not Found')
      end

      it 'returns failure' do
        result = described_class.execute(namespace: namespace, name: name)

        expect(result).to be_failure
      end

      it 'includes an error message' do
        result = described_class.execute(namespace: namespace, name: name)

        expect(result.message).to include('Failed to fetch buildpack details')
      end
    end

    context 'with different namespace and name' do
      let(:namespace) { 'different-namespace' }
      let(:name) { 'different-buildpack' }

      before do
        stub_request(:get, "https://registry.buildpacks.io/api/v1/buildpacks/#{namespace}/#{name}")
          .to_return(status: 200, body: fixture_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'constructs the correct URL' do
        described_class.execute(namespace: namespace, name: name)

        expect(WebMock).to have_requested(:get, "https://registry.buildpacks.io/api/v1/buildpacks/#{namespace}/#{name}")
      end
    end
  end
end
