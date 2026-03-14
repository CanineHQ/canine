require 'rails_helper'

RSpec.describe Api::AddOns::ShowViewModel do
  let(:cluster) { create(:cluster) }
  let(:add_on) { create(:add_on, cluster: cluster) }
  let(:service) { double("service") }
  let(:view_model) { described_class.new(add_on, service) }

  let(:mock_port) { double(port: 6379) }
  let(:mock_endpoint) do
    double(
      metadata: double(name: "redis-master"),
      spec: double(ports: [ mock_port ])
    )
  end
  let(:mock_ingress) do
    double(
      spec: double(
        rules: [
          double(
            host: "redis.example.com",
            http: double(
              paths: [
                double(backend: double(service: double(name: "redis-master")))
              ]
            )
          )
        ]
      )
    )
  end

  before do
    allow(service).to receive(:get_endpoints).and_return([ mock_endpoint ])
    allow(service).to receive(:get_ingresses).and_return([ mock_ingress ])
    allow(service).to receive(:respond_to?).with(:internal_url).and_return(false)
  end

  describe "#as_json" do
    subject(:result) { view_model.as_json }

    it "returns base fields" do
      expect(result).to include(
        id: add_on.id,
        name: add_on.name,
        namespace: add_on.namespace,
        chart_url: add_on.chart_url,
        chart_type: add_on.chart_type,
        repository_url: add_on.repository_url,
        version: add_on.version,
        status: add_on.status,
        install_stage: add_on.install_stage,
        cluster_id: add_on.cluster_id,
        cluster_name: cluster.name
      )
    end

    it "includes endpoints with internal and external urls" do
      expect(result[:endpoints]).to eq([
        {
          name: "redis-master",
          internal_urls: [ "redis-master.#{add_on.name}.svc.cluster.local:6379" ],
          external_urls: [ "redis.example.com" ]
        }
      ])
    end

    context "when endpoint fetch fails" do
      before do
        allow(service).to receive(:get_endpoints).and_raise(StandardError, "connection refused")
      end

      it "returns empty endpoints with error message" do
        expect(result[:endpoints]).to eq([])
        expect(result[:endpoints_error]).to include("connection refused")
      end
    end

    context "when service responds to internal_url" do
      before do
        allow(service).to receive(:respond_to?).with(:internal_url).and_return(true)
        allow(service).to receive(:internal_url).and_return("redis://redis-master:6379")
      end

      it "includes connection_url" do
        expect(result[:connection_url]).to eq("redis://redis-master:6379")
      end
    end

    context "when internal_url raises an error" do
      before do
        allow(service).to receive(:respond_to?).with(:internal_url).and_return(true)
        allow(service).to receive(:internal_url).and_raise(StandardError, "unavailable")
      end

      it "returns connection_url_error" do
        expect(result[:connection_url_error]).to include("unavailable")
      end
    end
  end
end
