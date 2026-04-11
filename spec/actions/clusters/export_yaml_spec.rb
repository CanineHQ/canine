require 'rails_helper'

RSpec.describe Clusters::ExportYaml do
  let(:cluster) { create(:cluster, name: "production-cluster") }
  let(:project) { create(:project, cluster: cluster, name: "my-app", namespace: "my-app-ns") }

  let!(:web_service) do
    service = create(:service, project: project, name: "web", service_type: :web_service,
                     container_port: 3000, allow_public_networking: true)
    create(:domain, service: service, domain_name: "myapp.example.com")
    service
  end

  let!(:worker_service) do
    create(:service, :background_service, project: project, name: "worker", command: "bundle exec sidekiq")
  end

  let!(:config_var) { create(:environment_variable, project: project, name: "DATABASE_URL", value: "postgres://localhost/myapp") }
  let!(:secret_var) { create(:environment_variable, :secret, project: project, name: "SECRET_KEY_BASE", value: "supersecret123") }
  let!(:volume) { create(:volume, project: project, name: "data-volume", mount_path: "/data", size: "20Gi") }

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
    { "apiVersion" => "v1", "kind" => "ConfigMap",
      "metadata" => { "name" => "my-app", "namespace" => "my-app-ns", "labels" => { "caninemanaged" => "true" } },
      "data" => {
        "RAILS_ENV" => "production",
        "SENTRY_AUTH_TOKEN" => "d874982b4bdf2ed96a9683080581d73004724196",
        "ANALYTICS_DATABASE_URL" => "postgresql://user:pass@db.example.com:5432/analytics"
      } }.to_yaml
  end

  let(:secret_yaml) do
    { "apiVersion" => "v1", "kind" => "Secret",
      "metadata" => { "name" => "my-app", "namespace" => "my-app-ns", "labels" => { "caninemanaged" => "true" } },
      "data" => { "SECRET_KEY_BASE" => Base64.strict_encode64("supersecret123"),
                  "DATABASE_URL" => Base64.strict_encode64("postgres://user:pass@localhost/myapp") } }.to_yaml
  end

  let(:web_deployment_yaml) do
    { "apiVersion" => "apps/v1", "kind" => "Deployment",
      "metadata" => { "name" => "web", "namespace" => "my-app-ns", "labels" => { "caninemanaged" => "true", "app" => "web" } },
      "spec" => { "replicas" => 1, "template" => {
        "metadata" => { "annotations" => { "rolloutTimestamp" => "1775600295" }, "labels" => { "app" => "web" } },
        "spec" => { "containers" => [ {
          "name" => "web",
          "image" => "ghcr.io/org/app:main@sha256:abc123def456",
          "imagePullPolicy" => "IfNotPresent",
          "ports" => [ { "containerPort" => 3000 } ]
        } ] }
      } } }.to_yaml
  end

  let(:web_service_yaml) do
    { "apiVersion" => "v1", "kind" => "Service",
      "metadata" => { "name" => "web-service", "namespace" => "my-app-ns", "labels" => { "caninemanaged" => "true", "app" => "web" } },
      "spec" => { "ports" => [ { "port" => 80, "targetPort" => 3000 } ], "selector" => { "app" => "web" } } }.to_yaml
  end

  let(:ingress_yaml) do
    { "apiVersion" => "networking.k8s.io/v1", "kind" => "Ingress",
      "metadata" => { "name" => "web-ingress", "namespace" => "my-app-ns", "labels" => { "caninemanaged" => "true" } },
      "spec" => { "rules" => [ { "host" => "myapp.example.com", "http" => { "paths" => [ { "path" => "/", "pathType" => "Prefix",
        "backend" => { "service" => { "name" => "web-service", "port" => { "number" => 80 } } } } ] } } ] } }.to_yaml
  end

  let(:worker_deployment_yaml) do
    { "apiVersion" => "apps/v1", "kind" => "Deployment",
      "metadata" => { "name" => "worker", "namespace" => "my-app-ns", "labels" => { "caninemanaged" => "true", "app" => "worker" } },
      "spec" => { "replicas" => 1, "template" => {
        "metadata" => { "annotations" => { "rolloutTimestamp" => "1775600296" }, "labels" => { "app" => "worker" } },
        "spec" => { "containers" => [ {
          "name" => "worker",
          "image" => "ghcr.io/org/app:main@sha256:abc123def456",
          "imagePullPolicy" => "IfNotPresent",
          "command" => [ "bundle", "exec", "sidekiq" ],
          "resources" => nil
        } ] }
      } } }.to_yaml
  end

  let!(:deployment) do
    create(:deployment, build: build, status: :completed, manifests: manifests)
  end

  describe '.execute' do
    it 'sanitizes manifests for ejection with all includes' do
      result = described_class.execute(cluster: cluster, include_configmaps: true, include_secrets: true)

      expect(result).to be_success
      entries = extract_zip_entries(result.zip_data)
      expect(entries.keys.size).to eq(6)

      # Deployments: image replaced, canine metadata stripped, empty resources cleaned
      web_deploy = YAML.safe_load(entries["production-cluster/my-app-ns/deployment-web.yaml"])
      expect(web_deploy["metadata"]["labels"]).to eq("app" => "web")
      expect(web_deploy.dig("spec", "template", "metadata", "annotations")).to be_nil
      container = web_deploy.dig("spec", "template", "spec", "containers", 0)
      expect(container["image"]).to eq("${IMAGE}")
      expect(container).not_to have_key("imagePullPolicy")

      worker_deploy = YAML.safe_load(entries["production-cluster/my-app-ns/deployment-worker.yaml"])
      worker_container = worker_deploy.dig("spec", "template", "spec", "containers", 0)
      expect(worker_container["image"]).to eq("${IMAGE}")
      expect(worker_container).not_to have_key("resources")
      expect(worker_container["command"]).to eq([ "bundle", "exec", "sidekiq" ])

      # Secrets: all values replaced with placeholder
      secret = YAML.safe_load(entries["production-cluster/my-app-ns/secret-my-app.yaml"])
      expect(secret["metadata"]["labels"]).to be_nil
      expect(secret["data"].values).to all(eq("<REPLACE_ME>"))

      # ConfigMap: sensitive values replaced, safe values preserved
      config = YAML.safe_load(entries["production-cluster/my-app-ns/configmap-my-app.yaml"])
      expect(config["data"]["RAILS_ENV"]).to eq("production")
      expect(config["data"]["SENTRY_AUTH_TOKEN"]).to eq("<REPLACE_ME>")
      expect(config["data"]["ANALYTICS_DATABASE_URL"]).to eq("<REPLACE_ME>")
    end

    it 'excludes configmaps when include_configmaps is false' do
      result = described_class.execute(cluster: cluster, include_configmaps: false, include_secrets: true)
      entries = extract_zip_entries(result.zip_data)

      expect(entries.keys).not_to include("production-cluster/my-app-ns/configmap-my-app.yaml")
      expect(entries.keys).to include("production-cluster/my-app-ns/secret-my-app.yaml")
    end

    it 'excludes secrets when include_secrets is false' do
      result = described_class.execute(cluster: cluster, include_configmaps: true, include_secrets: false)
      entries = extract_zip_entries(result.zip_data)

      expect(entries.keys).to include("production-cluster/my-app-ns/configmap-my-app.yaml")
      expect(entries.keys).not_to include("production-cluster/my-app-ns/secret-my-app.yaml")
    end

    it 'returns an empty zip when cluster has no projects with manifests' do
      empty_cluster = create(:cluster, name: "empty-cluster")

      result = described_class.execute(cluster: empty_cluster, include_configmaps: true, include_secrets: false)

      expect(result).to be_success
      entries = extract_zip_entries(result.zip_data)
      expect(entries).to be_empty
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
