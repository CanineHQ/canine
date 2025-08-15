class K8::Connection
  attr_reader :cluster, :user
  def initialize(cluster, user)
    @cluster = cluster
    @user = user
  end

  def kubeconfig
    # If the cluster has a kubeconfig, use it.
    if cluster.kubeconfig.present?
      return cluster.kubeconfig
    else
      K8Stack.fetch_kubeconfig(cluster, user)
    end
  end
end