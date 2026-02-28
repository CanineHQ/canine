class Clusters::InstallGatewayApi
  extend LightService::Action

  CRDS_URL = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml".freeze

  expects :cluster, :kubectl

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl

    cluster.info("Checking if Gateway API CRDs are already installed...", color: :yellow)

    begin
      kubectl.call("get crd gateways.gateway.networking.k8s.io")
      cluster.success("Gateway API CRDs are already installed")
    rescue Cli::CommandFailedError
      cluster.info("Gateway API CRDs not detected, installing...", color: :yellow)

      begin
        kubectl.call("apply -f #{CRDS_URL}")
        cluster.success("Gateway API CRDs installed successfully")
      rescue StandardError => e
        cluster.failed!
        cluster.error("Gateway API CRDs failed to install")
        context.fail_and_return!("Gateway API CRD install failed: #{e.message}")
      end
    end
  end
end
