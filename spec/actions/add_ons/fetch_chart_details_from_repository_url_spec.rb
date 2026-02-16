require 'rails_helper'

RSpec.describe AddOns::FetchChartDetailsFromRepositoryUrl do
  let(:repo_url) { "https://serhanekicii.github.io/openclaw-helm" }
  let(:index_url) { "#{repo_url}/index.yaml" }
  let(:index_yaml) { File.read(Rails.root.join("spec/resources/helm/repository_index/openclaw.yaml")) }

  describe "successful fetch" do
    before do
      stub_request(:get, index_url)
        .to_return(status: 200, body: index_yaml, headers: { "Content-Type" => "text/yaml" })
    end

    it "fetches and parses repository index" do
      result = described_class.execute(repo_url: repo_url)

      expect(result.success?).to be true
      expect(result.charts).to be_a(Hash)
      expect(result.charts).to have_key("openclaw")
    end

    it "extracts chart versions correctly" do
      result = described_class.execute(repo_url: repo_url)

      openclaw_versions = result.charts["openclaw"]
      expect(openclaw_versions).to be_an(Array)
      expect(openclaw_versions).to include("1.3.16")
      expect(openclaw_versions.all? { |v| v.is_a?(String) }).to be true
    end

    it "handles trailing slash in repo_url" do
      stub_request(:get, "#{repo_url}/index.yaml")
        .to_return(status: 200, body: index_yaml, headers: { "Content-Type" => "text/yaml" })

      result = described_class.execute(repo_url: "#{repo_url}/")

      expect(result.success?).to be true
      expect(result.charts).to have_key("openclaw")
    end
  end

  describe "error handling" do
    context "when HTTP request fails" do
      before do
        stub_request(:get, index_url)
          .to_return(status: 404, body: "Not Found")
      end

      it "returns failure with error message" do
        result = described_class.execute(repo_url: repo_url)

        expect(result.failure?).to be true
        expect(result.message).to include("Failed to fetch repository index: 404")
      end
    end

    context "when YAML is invalid" do
      before do
        stub_request(:get, index_url)
          .to_return(status: 200, body: "invalid: yaml: [", headers: { "Content-Type" => "text/yaml" })
      end

      it "returns failure with YAML error" do
        result = described_class.execute(repo_url: repo_url)

        expect(result.failure?).to be true
        expect(result.message).to include("Invalid YAML format")
      end
    end

    context "when index format is invalid" do
      before do
        stub_request(:get, index_url)
          .to_return(status: 200, body: "apiVersion: v1\ndata: {}", headers: { "Content-Type" => "text/yaml" })
      end

      it "returns failure with format error" do
        result = described_class.execute(repo_url: repo_url)

        expect(result.failure?).to be true
        expect(result.message).to eq("Invalid repository index format")
      end
    end

    context "when network timeout occurs" do
      before do
        stub_request(:get, index_url).to_timeout
      end

      it "returns failure with timeout error" do
        result = described_class.execute(repo_url: repo_url)

        expect(result.failure?).to be true
        expect(result.message).to include("Failed to fetch repository index")
      end
    end

    context "when socket error occurs" do
      before do
        stub_request(:get, index_url).to_raise(SocketError.new("getaddrinfo: Name or service not known"))
      end

      it "returns failure with socket error" do
        result = described_class.execute(repo_url: repo_url)

        expect(result.failure?).to be true
        expect(result.message).to include("Failed to fetch repository index")
      end
    end
  end

  describe "edge cases" do
    context "when entries is empty" do
      let(:empty_index) do
        <<~YAML
          apiVersion: v1
          entries: {}
        YAML
      end

      before do
        stub_request(:get, index_url)
          .to_return(status: 200, body: empty_index, headers: { "Content-Type" => "text/yaml" })
      end

      it "returns empty charts hash" do
        result = described_class.execute(repo_url: repo_url)

        expect(result.success?).to be true
        expect(result.charts).to eq({})
      end
    end

    context "when chart has no versions" do
      let(:no_versions_index) do
        <<~YAML
          apiVersion: v1
          entries:
            mychart: []
        YAML
      end

      before do
        stub_request(:get, index_url)
          .to_return(status: 200, body: no_versions_index, headers: { "Content-Type" => "text/yaml" })
      end

      it "returns empty array for chart" do
        result = described_class.execute(repo_url: repo_url)

        expect(result.success?).to be true
        expect(result.charts["mychart"]).to eq([])
      end
    end
  end
end
