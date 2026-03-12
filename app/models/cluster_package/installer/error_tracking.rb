class ClusterPackage::Installer::ErrorTracking < ClusterPackage::Installer::Base
  NAMESPACE = Clusters::Install::DEFAULT_NAMESPACE
  SERVICE_NAME = "error-tracking"

  def install!(kubectl)
    install_helm(kubectl)
    update_cluster_url!
  end

  def uninstall!(kubectl)
    super
    package.cluster.update!(error_tracking_url: nil)
  end

  private

  def install_helm(kubectl)
    helm = build_helm(kubectl)
    chart_path = Rails.root.join("error_tracking", "helm").to_s

    values = build_values
    image_repo = package.config&.dig("image_repository") || definition["values"]["image"]["repository"]
    image_tag = package.config&.dig("image_tag") || definition["values"]["image"]["tag"]
    values["image"] = { "repository" => image_repo, "tag" => image_tag }

    helm.install(
      SERVICE_NAME,
      chart_path,
      values: values,
      namespace: NAMESPACE,
      create_namespace: true
    )
  end

  def update_cluster_url!
    url = "http://#{SERVICE_NAME}.#{NAMESPACE}.svc.cluster.local:3001"
    package.cluster.update!(error_tracking_url: url)
  end
end
