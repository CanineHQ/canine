class Clusters::InstallEnvoyGateway
  extend LightService::Action

  CHART_NAME = "envoy-gateway".freeze
  CHART_URL = "oci://docker.io/envoyproxy/gateway-helm".freeze

  expects :cluster, :kubectl, :connection

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    connection = context.connection
    namespace = Clusters::Install::DEFAULT_NAMESPACE

    cluster.info("Checking if Envoy Gateway is already installed...", color: :yellow)

    begin
      kubectl.("get deployment envoy-gateway -n #{namespace}")
      cluster.success("Envoy Gateway is already installed")
    rescue Cli::CommandFailedError
      cluster.info("Envoy Gateway not detected, installing...", color: :yellow)

      begin
        runner = Cli::RunAndLog.new(cluster)
        helm = K8::Helm::Client.connect(connection, runner)

        helm.install(
          CHART_NAME,
          CHART_URL,
          namespace: namespace
        )

        cluster.success("Envoy Gateway installed successfully")
      rescue StandardError => e
        cluster.failed!
        cluster.error("Envoy Gateway failed to install")
        context.fail_and_return!("Helm install failed: #{e.message}")
      end
    end

    # Ensure the shared Gateway resource exists
    cluster.info("Creating shared Gateway resource...", color: :yellow)
    begin
      gateway_yaml = K8::Shared::Gateway.new(namespace: namespace).to_yaml
      kubectl.apply_yaml(gateway_yaml)
      cluster.success("Shared Gateway resource created")
    rescue StandardError => e
      cluster.error("Failed to create Gateway resource: #{e.message}")
    end
  end
end
