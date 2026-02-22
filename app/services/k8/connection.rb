class K8::Connection
  attr_reader :clusterable, :user, :allow_anonymous
  def initialize(clusterable, user, allow_anonymous: false)
    @clusterable = clusterable
    @user = user
    @allow_anonymous = allow_anonymous
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
    config = if cluster.kubeconfig.present?
      cluster.kubeconfig
    else
      raise StandardError.new("No stack manager found") if stack_manager.blank?
      stack = stack_manager.stack.connect(user, allow_anonymous:)
      stack.fetch_kubeconfig(cluster)
    end

    if Rails.configuration.remap_localhost.present?
      remap_host = Rails.configuration.remap_localhost
      config.dup.tap do |remapped|
        remapped['clusters']&.each do |c|
          c['cluster']['server'] = K8::Kubeconfig.remap_localhost(c['cluster']['server'], remap_host)
        end
      end
    else
      config
    end
  end

  def stack_manager
    cluster.account.stack_manager
  end

  %i[add_on project].each do |method_name|
    define_method method_name do
      class_name = method_name.to_s.classify
      raise "`clusterable` is not a #{class_name}" unless clusterable.is_a?(class_name.constantize)
      clusterable
    end
  end
end
