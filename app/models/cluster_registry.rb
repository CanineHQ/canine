# The image registry the "registry" cluster package runs inside a cluster (resources/k8/shared/cluster_registry.yaml).
# Builds push to its Service over cluster DNS; nodes pull through a proxy on each node's loopback, which containerd
# allows over plain HTTP. The two hosts reach the same registry, so an image pushed to one is pulled from the other.
class ClusterRegistry
  PACKAGE_NAME = "registry".freeze
  USERNAME = "canine".freeze
  SERVICE_HOST = "canine-registry.#{Clusters::Install::DEFAULT_NAMESPACE}.svc.cluster.local:5000".freeze
  NODE_PORT = 5000
  NODE_HOST = "127.0.0.1:#{NODE_PORT}".freeze

  attr_reader :cluster

  def initialize(cluster)
    @cluster = cluster
  end

  def package
    cluster.cluster_packages.find_by(name: PACKAGE_NAME)
  end

  def installed?
    package&.installed? || false
  end

  def password
    package&.config&.dig("password")
  end

  def push_reference(image)
    "#{SERVICE_HOST}/#{image}"
  end

  def pull_reference(image)
    "#{NODE_HOST}/#{image}"
  end

  # Base64 encoded docker config.json, as an image pull secret wants it
  def docker_config_json(host)
    Providers::GenerateConfigJson.create_docker_json_structure(USERNAME, password, host)
  end
end
