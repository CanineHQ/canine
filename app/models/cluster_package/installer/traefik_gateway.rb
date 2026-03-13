class ClusterPackage::Installer::TraefikGateway < ClusterPackage::Installer::Base
  def install!(kubectl)
    install_gateway_api_crds(kubectl)
    install_helm(kubectl)
  end

  private

  def install_gateway_api_crds(kubectl)
    cluster = kubectl.connection.cluster
    cluster.info("Installing Gateway API CRDs...", color: :yellow)
    crds_url = definition["gateway_api_crds_url"]
    kubectl.("apply -f #{crds_url}")
    cluster.success("Gateway API CRDs installed")
  end
end
