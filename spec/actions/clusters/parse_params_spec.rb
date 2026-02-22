require 'rails_helper'

RSpec.describe Clusters::ParseParams do
  let(:kubeconfig_yaml) { File.read(Rails.root.join('spec/resources/k8/kubeconfig.yml')) }

  before do
    allow(Rails.configuration).to receive(:remap_localhost).and_return("")
  end

  describe ".parse_params" do
    it "parses kubeconfig from YAML editor" do
      params = ActionController::Parameters.new(
        cluster: {
          name: "test-cluster",
          cluster_type: "k8s",
          kubeconfig_yaml_format: "true",
          kubeconfig: kubeconfig_yaml
        }
      )

      result = described_class.parse_params(params)
      expect(result[:name]).to eq("test-cluster")
      expect(result[:kubeconfig]).to be_a(ActionController::Parameters)
      expect(result[:kubeconfig]["apiVersion"]).to eq("v1")
    end

    it "parses kubeconfig from file upload" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/resources/k8/kubeconfig.yml'), 'application/x-yaml'
      )
      params = ActionController::Parameters.new(
        cluster: {
          name: "test-cluster",
          cluster_type: "k8s",
          kubeconfig_yaml_format: "false",
          kubeconfig_file: file
        }
      )

      result = described_class.parse_params(params)
      expect(result[:kubeconfig]["apiVersion"]).to eq("v1")
      expect(result[:kubeconfig]["clusters"]).to be_present
    end

    it "parses k3s cluster with ip_address and kubeconfig output" do
      params = ActionController::Parameters.new(
        cluster: {
          name: "k3s-cluster",
          cluster_type: "k3s",
          ip_address: "192.168.1.100",
          k3s_kubeconfig_output: kubeconfig_yaml
        }
      )

      result = described_class.parse_params(params)
      expect(result[:kubeconfig]["clusters"][0]["cluster"]["server"]).to eq("https://192.168.1.100:6443")
    end

    it "parses local_k3s cluster with kubeconfig output" do
      params = ActionController::Parameters.new(
        cluster: {
          name: "local-k3s",
          cluster_type: "local_k3s",
          local_k3s_kubeconfig_output: kubeconfig_yaml
        }
      )

      result = described_class.parse_params(params)
      expect(result[:kubeconfig]["apiVersion"]).to eq("v1")
    end

    it "permits only allowed params" do
      params = ActionController::Parameters.new(
        cluster: {
          name: "test",
          cluster_type: "k8s",
          skip_tls_verify: true,
          kubeconfig_yaml_format: "true",
          kubeconfig: kubeconfig_yaml,
          some_random_field: "should be filtered"
        }
      )

      result = described_class.parse_params(params)
      expect(result[:name]).to eq("test")
      expect(result[:skip_tls_verify]).to eq(true)
      expect(result).not_to have_key(:some_random_field)
    end
  end

  describe ".remap_localhost" do
    it "remaps localhost to the given host" do
      kubeconfig = YAML.safe_load(kubeconfig_yaml)
      kubeconfig['clusters'][0]['cluster']['server'] = "https://localhost:6443"

      result = described_class.remap_localhost(kubeconfig, "host.docker.internal")
      expect(result["clusters"][0]["cluster"]["server"]).to include("host.docker.internal")
    end

    it "doesn't remap non-localhost servers" do
      kubeconfig = YAML.safe_load(kubeconfig_yaml)
      result = described_class.remap_localhost(kubeconfig, "host.docker.internal")
      expect(result["clusters"][0]["cluster"]["server"]).not_to include("host.docker.internal")
    end
  end
end
