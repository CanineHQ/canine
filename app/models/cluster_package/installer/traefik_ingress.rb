class ClusterPackage::Installer::TraefikIngress < ClusterPackage::Installer::Base
  def install!(kubectl)
    if traefik_present?(kubectl)
      package.cluster.info("Traefik already installed, skipping", color: :yellow)
      return
    end

    super
  end

  private

  def traefik_present?(kubectl)
    kubectl.(%w[get ingressclass traefik])
    true
  rescue Cli::CommandFailedError
    false
  end
end
