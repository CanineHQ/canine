# Installs the in-cluster image registry (see ClusterRegistry). Its password is generated here and kept in the
# package config, so it survives reinstalls; uninstalling deletes the registry's volume and every image in it.
class ClusterPackage::Installer::Registry < ClusterPackage::Installer::Base
  RESOURCES = %w[
    deployment/canine-registry service/canine-registry daemonset/canine-registry-proxy
    configmap/canine-registry-proxy secret/canine-registry-auth persistentvolumeclaim/canine-registry
  ].freeze

  def install!(kubectl)
    password = package.config&.dig("password").presence || SecureRandom.hex(32)
    package.update!(config: (package.config || {}).merge("password" => password))

    kubectl.apply_yaml(K8::Shared::ClusterRegistry.new(password:).to_yaml)
    kubectl.(%W[rollout status deployment/canine-registry -n #{Clusters::Install::DEFAULT_NAMESPACE} --timeout=5m])
  end

  def uninstall!(kubectl)
    if BuildConfiguration.joins(:project).where(cluster_registry: true, projects: { cluster_id: package.cluster_id }).exists?
      raise "Switch this cluster's projects to another registry before uninstalling the image registry"
    end

    kubectl.(%W[delete -n #{Clusters::Install::DEFAULT_NAMESPACE} --ignore-not-found] + RESOURCES)
  end
end
