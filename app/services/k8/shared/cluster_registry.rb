class K8::Shared::ClusterRegistry < K8::Base
  attr_accessor :htpasswd, :storage_size, :namespace

  def initialize(password:, storage_size: "20Gi", namespace: Clusters::Install::DEFAULT_NAMESPACE)
    @htpasswd = "#{::ClusterRegistry::USERNAME}:#{BCrypt::Password.create(password)}"
    @storage_size = storage_size
    @namespace = namespace
  end

  def node_port
    ::ClusterRegistry::NODE_PORT
  end

  def service_host
    ::ClusterRegistry::SERVICE_HOST
  end
end
