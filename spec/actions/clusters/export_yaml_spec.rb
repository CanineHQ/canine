require 'rails_helper'

RSpec.describe Clusters::ExportYaml do
  let(:cluster) { create(:cluster, name: "production-cluster") }
  let(:project) { create(:project, cluster: cluster, name: "my-app", namespace: "my-app-ns") }

  # Project with two services: a web service with a domain and a background worker
  let!(:web_service) do
    service = create(:service, project: project, name: "web", service_type: :web_service,
                     container_port: 3000, allow_public_networking: true)
    create(:domain, service: service, domain_name: "myapp.example.com")
    service
  end

  let!(:worker_service) do
    create(:service, :background_service, project: project, name: "worker", command: "bundle exec sidekiq")
  end

  # Environment variables (config + secret)
  let!(:config_var) { create(:environment_variable, project: project, name: "DATABASE_URL", value: "postgres://localhost/myapp") }
  let!(:secret_var) { create(:environment_variable, :secret, project: project, name: "SECRET_KEY_BASE", value: "supersecret123") }

  # Volume
  let!(:volume) { create(:volume, project: project, name: "data-volume", mount_path: "/data", size: "20Gi") }

  # Build + deployment with manifests simulating what the deployment service would track
  let(:build) { create(:build, project: project, commit_sha: "abc123", commit_message: "Deploy v1") }
  let(:manifests) do
    {
      "configmap/my-app" => configmap_yaml,
      "secret/my-app" => secret_yaml,
      "deployment/web" => web_deployment_yaml,
      "service/web-service" => web_service_yaml,
      "ingress/web-ingress" => ingress_yaml,
      "deployment/worker" => worker_deployment_yaml
    }
  end

  let(:configmap_yaml) do
    { "apiVersion" => "v1", "kind" => "ConfigMap", "metadata" => { "name" => "my-app", "namespace" => "my-app-ns" },
      "data" => { "DATABASE_URL" => "postgres://localhost/myapp" } }.to_yaml
  end

  let(:secret_yaml) do
    { "apiVersion" => "v1", "kind" => "Secret", "metadata" => { "name" => "my-app", "namespace" => "my-app-ns" },
      "data" => { "SECRET_KEY_BASE" => Base64.strict_encode64("supersecret123") } }.to_yaml
  end

  let(:web_deployment_yaml) do
    { "apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => { "name" => "web", "namespace" => "my-app-ns" },
      "spec" => { "replicas" => 1, "template" => { "spec" => { "containers" => [ { "name" => "web", "image" => "myapp:latest", "ports" => [ { "containerPort" => 3000 } ] } ] } } } }.to_yaml
  end

  let(:web_service_yaml) do
    { "apiVersion" => "v1", "kind" => "Service", "metadata" => { "name" => "web-service", "namespace" => "my-app-ns" },
      "spec" => { "ports" => [ { "port" => 80, "targetPort" => 3000 } ], "selector" => { "app" => "web" } } }.to_yaml
  end

  let(:ingress_yaml) do
    { "apiVersion" => "networking.k8s.io/v1", "kind" => "Ingress", "metadata" => { "name" => "web-ingress", "namespace" => "my-app-ns" },
      "spec" => { "rules" => [ { "host" => "myapp.example.com", "http" => { "paths" => [ { "path" => "/", "pathType" => "Prefix",
        "backend" => { "service" => { "name" => "web-service", "port" => { "number" => 80 } } } } ] } } ] } }.to_yaml
  end

  let(:worker_deployment_yaml) do
    { "apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => { "name" => "worker", "namespace" => "my-app-ns" },
      "spec" => { "replicas" => 1, "template" => { "spec" => { "containers" => [ { "name" => "worker", "image" => "myapp:latest", "command" => [ "bundle", "exec", "sidekiq" ] } ] } } } }.to_yaml
  end

  let!(:deployment) do
    create(:deployment, build: build, status: :completed, manifests: manifests)
  end

  describe '.execute' do
    it 'exports all tracked manifests from the latest completed deployment as a zip' do
      result = described_class.execute(cluster: cluster)

      expect(result).to be_success
      expect(result.filename).to eq("production-cluster.zip")

      entries = extract_zip_entries(result.zip_data)

      # All 6 manifests should be present
      expect(entries.keys).to contain_exactly(
        "production-cluster/my-app-ns/configmap-my-app.yaml",
        "production-cluster/my-app-ns/secret-my-app.yaml",
        "production-cluster/my-app-ns/deployment-web.yaml",
        "production-cluster/my-app-ns/service-web-service.yaml",
        "production-cluster/my-app-ns/ingress-web-ingress.yaml",
        "production-cluster/my-app-ns/deployment-worker.yaml"
      )

      # Verify manifest content is preserved
      web_deploy = YAML.safe_load(entries["production-cluster/my-app-ns/deployment-web.yaml"])
      expect(web_deploy["kind"]).to eq("Deployment")
      expect(web_deploy["metadata"]["name"]).to eq("web")
      expect(web_deploy.dig("spec", "template", "spec", "containers", 0, "ports", 0, "containerPort")).to eq(3000)

      worker_deploy = YAML.safe_load(entries["production-cluster/my-app-ns/deployment-worker.yaml"])
      expect(worker_deploy["metadata"]["name"]).to eq("worker")
      expect(worker_deploy.dig("spec", "template", "spec", "containers", 0, "command")).to eq([ "bundle", "exec", "sidekiq" ])

      config = YAML.safe_load(entries["production-cluster/my-app-ns/configmap-my-app.yaml"])
      expect(config["data"]["DATABASE_URL"]).to eq("postgres://localhost/myapp")

      secret = YAML.safe_load(entries["production-cluster/my-app-ns/secret-my-app.yaml"])
      expect(secret["data"]["SECRET_KEY_BASE"]).to eq(Base64.strict_encode64("supersecret123"))

      ingress = YAML.safe_load(entries["production-cluster/my-app-ns/ingress-web-ingress.yaml"])
      expect(ingress.dig("spec", "rules", 0, "host")).to eq("myapp.example.com")

      svc = YAML.safe_load(entries["production-cluster/my-app-ns/service-web-service.yaml"])
      expect(svc.dig("spec", "ports", 0, "targetPort")).to eq(3000)
    end

    it 'uses the latest completed deployment, not failed or in-progress ones' do
      # Create a newer failed deployment with different manifests
      newer_build = create(:build, project: project, commit_sha: "def456")
      create(:deployment, build: newer_build, status: :failed, manifests: { "deployment/web" => "bad" })

      result = described_class.execute(cluster: cluster)
      entries = extract_zip_entries(result.zip_data)

      # Should still have all 6 manifests from the completed deployment
      expect(entries.keys.size).to eq(6)
    end

    it 'skips projects with no completed deployments' do
      other_project = create(:project, cluster: cluster, name: "new-app", namespace: "new-app-ns")
      other_build = create(:build, project: other_project, commit_sha: "xyz789")
      create(:deployment, build: other_build, status: :in_progress, manifests: { "deployment/app" => "pending" })

      result = described_class.execute(cluster: cluster)
      entries = extract_zip_entries(result.zip_data)

      # Only the original project's manifests, not the in-progress one
      expect(entries.keys.all? { |k| k.include?("my-app-ns") }).to be true
    end

    it 'returns an empty zip when cluster has no projects with manifests' do
      empty_cluster = create(:cluster, name: "empty-cluster")

      result = described_class.execute(cluster: empty_cluster)

      expect(result).to be_success
      expect(result.filename).to eq("empty-cluster.zip")
      entries = extract_zip_entries(result.zip_data)
      expect(entries).to be_empty
    end

    it 'exports multiple projects independently' do
      second_project = create(:project, cluster: cluster, name: "api-app", namespace: "api-app-ns")
      second_build = create(:build, project: second_project, commit_sha: "second123")
      api_manifest = { "apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => { "name" => "api", "namespace" => "api-app-ns" },
                       "spec" => { "replicas" => 2 } }.to_yaml
      create(:deployment, build: second_build, status: :completed, manifests: { "deployment/api" => api_manifest })

      result = described_class.execute(cluster: cluster)
      entries = extract_zip_entries(result.zip_data)

      my_app_entries = entries.keys.select { |k| k.include?("my-app-ns") }
      api_entries = entries.keys.select { |k| k.include?("api-app-ns") }

      expect(my_app_entries.size).to eq(6)
      expect(api_entries.size).to eq(1)
      expect(api_entries.first).to eq("production-cluster/api-app-ns/deployment-api.yaml")

      api_deploy = YAML.safe_load(entries["production-cluster/api-app-ns/deployment-api.yaml"])
      expect(api_deploy.dig("spec", "replicas")).to eq(2)
    end
  end

  private

  def extract_zip_entries(zip_data)
    entries = {}
    Zip::InputStream.open(StringIO.new(zip_data)) do |io|
      while (entry = io.get_next_entry)
        entries[entry.name] = io.read
      end
    end
    entries
  end
end
