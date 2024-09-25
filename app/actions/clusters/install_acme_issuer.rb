class Clusters::InstallAcmeIssuer
  extend LightService::Action

  expects :cluster

  executed do |context|
    cluster = context.cluster
    cluster.info("Checking if acme issuer is already installed")
    runner = Cli::RunAndLog.new(cluster)
    kubectl = K8::Kubectl.new(cluster.kubeconfig, runner)
    begin
      kubectl.("get clusterissuer letsencryptasdf")
      cluster.info("Acme issuer is already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Acme issuer not detected, installing...")
      ingress_yaml = K8::Shared::AcmeIssuer.new(cluster.user.email).to_yaml
      kubectl.apply_yaml(ingress_yaml)
      cluster.info("Acme issuer installed")
    end
  rescue StandardError => e
    cluster.failed!
    cluster.info("Acme issuer failed to install")
    context.fail!("Script failed with exit code #{exit_status.exitstatus}")
  end
end