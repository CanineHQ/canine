class Clusters::InstallMetricServer
  extend LightService::Action

  expects :cluster, :kubectl

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    cluster.info("Checking if metric server is already installed...", color: :yellow)

    begin
      kubectl.("get deployment metrics-server -n kube-system")
      cluster.success("Metric server ingress controller is already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Metric server not detected, installing...", color: :yellow)
      kubectl.apply_yaml(Rails.root.join("resources", "k8", "shared", "metrics_server.yaml").read)
      cluster.success("Metric server installed successfully")
    end
  end
end
