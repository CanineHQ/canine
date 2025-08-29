class K8::Connection
  attr_reader :cluster, :user
  def initialize(cluster, user)
    @cluster = cluster
    @user = user
  end

  def kubeconfig
    cluster.kubeconfig
  end
end
