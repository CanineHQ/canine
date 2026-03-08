class ClusterPackage::Installer::TraefikGateway < ClusterPackage::Installer::Base
  def install!(kubectl)
    install_gateway_api_crds(kubectl)
    install_helm(kubectl)
    set_cluster_networking_mode(kubectl)
  end

  private

  def install_gateway_api_crds(kubectl)
    cluster = kubectl.connection.cluster
    cluster.info("Installing Gateway API CRDs...", color: :yellow)
    crds_url = definition["gateway_api_crds_url"]
    kubectl.("apply -f #{crds_url}")
    cluster.success("Gateway API CRDs installed")
  end

  def set_cluster_networking_mode(kubectl)
    cluster = kubectl.connection.cluster
    cluster.networking_mode = "gateway"
    cluster.save!
    cluster.success("Cluster networking mode set to gateway")
  end
end
