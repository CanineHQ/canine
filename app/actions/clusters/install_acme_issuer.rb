class Clusters::InstallAcmeIssuer
  extend LightService::Action

  expects :cluster

  executed do |context|
    cluster = context.cluster
    cluster.info("Checking if acme issuer is already installed", color: :yellow)
    runner = Cli::RunAndLog.new(cluster)
    kubectl = K8::Kubectl.new(cluster.kubeconfig, runner)
    begin
      kubectl.("get clusterissuer letsencrypt -n #{Clusters::Install::DEFAULT_NAMESPACE}")
      cluster.success("Acme issuer is already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Acme issuer not detected, installing...", color: :yellow)
      acme_issuer_yaml = K8::Shared::AcmeIssuer.new(cluster.account.owner.email).to_yaml
      kubectl.apply_yaml(acme_issuer_yaml)
      cluster.success("Acme issuer installed")
    end
  rescue StandardError => e
    cluster.failed!
    cluster.error("Acme issuer failed to install")
  end
end
