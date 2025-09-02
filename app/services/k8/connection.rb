class K8::Connection
  attr_reader :clusterable, :user
  def initialize(clusterable, user)
    @clusterable = clusterable
    @user = user
  end

  def cluster
    klass = clusterable.class.name
    if klass == "Cluster"
      clusterable
    elsif klass == "Project"
      clusterable.cluster
    elsif klass == "AddOn"
      clusterable.cluster
    else
      raise "`clusterable` is not a Cluster, Project, or AddOn"
    end
  end

  def kubeconfig
    # If the cluster has a kubeconfig, use it.
    if cluster.kubeconfig.present?
      cluster.kubeconfig
    else
      K8Stack.fetch_kubeconfig(cluster, user)
    end
  end

  %i[add_on project].each do |method_name|
    define_method method_name do
      class_name = method_name.to_s.classify
      raise "`clusterable` is not a #{class_name}" unless clusterable.is_a?(class_name.constantize)
      clusterable
    end
  end
end
