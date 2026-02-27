class ClusterPackage::Installer::CertManager < ClusterPackage::Installer::Base
  def install!(kubectl)
    install_helm(kubectl)
    install_acme_issuer(kubectl)
  end

  private

  def install_acme_issuer(kubectl)
    cluster = kubectl.connection.cluster
    cluster.info("Installing ACME issuer...", color: :yellow)
    email = cluster.account.owner.email
    acme_issuer_yaml = K8::Shared::AcmeIssuer.new(email).to_yaml
    kubectl.apply_yaml(acme_issuer_yaml)
    cluster.success("ACME issuer installed")
  end
end
