require "rails_helper"
require "webmock/rspec"

RSpec.describe Portainer::Client do
  let(:portainer_url) { "https://portainer.example.com" }
  let(:portainer_token) { "test-token-123" }
  let(:client) { described_class.new(portainer_url, portainer_token) }

  describe "#endpoints" do
    let(:endpoints_json) { File.read(Rails.root.join("spec/resources/integrations/portainer/endpoints.json")) }

    before do
      stub_request(:get, "#{portainer_url}/api/endpoints")
        .with(headers: { "Authorization" => "Bearer #{portainer_token}" })
        .to_return(status: 200, body: endpoints_json, headers: { "Content-Type" => "application/json" })
    end

    it "fetches and parses endpoints correctly" do
      endpoints = client.endpoints

      expect(endpoints).to be_an(Array)
      expect(endpoints.length).to eq(2)

      # Check first endpoint
      first_endpoint = endpoints[0]
      expect(first_endpoint).to be_a(Portainer::Data::Endpoint)
      expect(first_endpoint.id).to eq(1)
      expect(first_endpoint.name).to eq("local")
      expect(first_endpoint.url).to eq("https://kubernetes.default.svc")

      # Check second endpoint
      second_endpoint = endpoints[1]
      expect(second_endpoint).to be_a(Portainer::Data::Endpoint)
      expect(second_endpoint.id).to eq(2)
      expect(second_endpoint.name).to eq("cluster-production")
      expect(second_endpoint.url).to eq("137.184.242.139:9001")
    end

    context "when the API request fails" do
      before do
        stub_request(:get, "#{portainer_url}/api/endpoints")
          .with(headers: { "Authorization" => "Bearer #{portainer_token}" })
          .to_return(status: 401, body: "Unauthorized")
      end

      it "raises an error" do
        expect { client.endpoints }.to raise_error(Portainer::Client::UnauthorizedError)
      end
    end
  end
end
