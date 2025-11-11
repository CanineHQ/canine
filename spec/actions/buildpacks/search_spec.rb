require 'rails_helper'

RSpec.describe Buildpacks::Search do
  describe '.execute' do
    let(:query) { 'ruby' }
    let(:fixture_path) { Rails.root.join('spec/resources/build_packs/search_ruby.json') }
    let(:fixture_response) { File.read(fixture_path) }

    before do
      stub_request(:get, "https://registry.buildpacks.io/api/v1/search")
        .with(query: { matches: query })
        .to_return(status: 200, body: fixture_response, headers: { 'Content-Type' => 'application/json' })
    end

    context 'when the API request is successful' do
      it 'returns success' do
        result = described_class.execute(query: query)

        expect(result).to be_success
      end

      it 'returns an array of BuildpackResult structs' do
        result = described_class.execute(query: query)

        expect(result.results).to be_an(Array)
        expect(result.results.first).to be_a(Buildpacks::Search::BuildpackResult)
      end

      it 'parses the latest buildpack information correctly' do
        result = described_class.execute(query: query)
        first_result = result.results.first

        expect(first_result.latest).to be_a(Buildpacks::Search::BuildpackLatest)
        expect(first_result.latest.namespace).to eq('paketo-buildpacks')
        expect(first_result.latest.name).to eq('ruby')
        expect(first_result.latest.description).to include('Ruby')
        expect(first_result.latest.licenses).to include('Apache-2.0')
      end

      it 'parses the versions array correctly' do
        result = described_class.execute(query: query)
        first_result = result.results.first

        expect(first_result.versions).to be_an(Array)
        expect(first_result.versions.first).to be_a(Buildpacks::Search::BuildpackVersion)
        expect(first_result.versions.first.version).to be_present
        expect(first_result.versions.first.link).to be_present
      end

      it 'handles multiple search results' do
        result = described_class.execute(query: query)

        expect(result.results.length).to be > 1
      end
    end

    context 'when the API request fails' do
      before do
        stub_request(:get, "https://registry.buildpacks.io/api/v1/search")
          .with(query: { matches: query })
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns failure' do
        result = described_class.execute(query: query)

        expect(result).to be_failure
      end

      it 'includes an error message' do
        result = described_class.execute(query: query)

        expect(result.message).to include('Failed to search buildpacks')
      end
    end
  end
end
