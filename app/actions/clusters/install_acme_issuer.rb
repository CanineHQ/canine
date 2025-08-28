class Clusters::InstallAcmeIssuer
  extend LightService::Action

  expects :cluster, :kubectl

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    cluster.info("Checking if acme issuer is already installed", color: :yellow)
    begin
      kubectl.("get clusterissuer letsencrypt -n #{Clusters::Install::DEFAULT_NAMESPACE}")
      cluster.success("Acme issuer is already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Acme issuer not detected, installing...", color: :yellow)
      cluster.info("Installing cert-manager...", color: :yellow)
      command = "bash #{Rails.root.join("resources", "k8", "scripts", "install_cert_manager.sh")}"

      kubectl.with_kube_config do |kubeconfig_file|
        begin
          runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path, "NAMESPACE" => Clusters::Install::DEFAULT_NAMESPACE })
          cluster.success("Cert-manager installed successfully")
        rescue Cli::CommandFailedError => e
          cluster.failed!
          cluster.error("Cert-manager failed to install")
          context.fail_and_return!("Script failed with exit code #{e.message}")
        end
      end

      cluster.info("Installing acme issuer...", color: :yellow)
      acme_issuer_yaml = K8::Shared::AcmeIssuer.new(cluster.account.owner.email).to_yaml
      kubectl.apply_yaml(acme_issuer_yaml)
      cluster.success("Acme issuer installed")
    end
  rescue StandardError => e
    cluster.failed!
    cluster.error("Acme issuer failed to install")
  end
end
