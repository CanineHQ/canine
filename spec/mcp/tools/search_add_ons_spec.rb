# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::SearchAddOns do
  it 'returns curated and Artifact Hub results' do
    hub_response = {
      "packages" => [
        {
          "name" => "redis",
          "description" => "Open source in-memory data store",
          "version" => "18.6.1",
          "repository" => { "name" => "bitnami", "url" => "https://charts.bitnami.com/bitnami" }
        }
      ]
    }
    allow(AddOns::HelmChartSearch).to receive(:execute).and_return(
      double(success?: true, response: hub_response)
    )

    response = described_class.call(query: 'redis', server_context: { user_id: 1 })
    result = JSON.parse(response.content.first[:text])

    expect(result['curated']).to be_an(Array)
    expect(result['curated'].first['chart_url']).to eq('bitnami/redis')
    expect(result['artifact_hub']).to be_an(Array)
    expect(result['artifact_hub'].first['name']).to eq('redis')
  end
end
