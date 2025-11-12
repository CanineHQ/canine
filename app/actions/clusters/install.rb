class Clusters::Install
  DEFAULT_NAMESPACE = "canine-system".freeze
  extend LightService::Organizer
  DEFAULT_RECIPE = [
    Clusters::IsReady,
    Clusters::CreateNamespace,
    Clusters::InstallNginxIngress,
    Clusters::InstallAcmeIssuer,
    Clusters::InstallMetricServer,
    Clusters::InstallTelepresence
  ]

  def self.recipe(cluster, user)
    recipe = if cluster.account.stack_manager.present? && cluster.kubeconfig.blank?
      stack_manager = cluster.account.stack_manager
      stack_manager.stack.connect(user).install_recipe
    else
      DEFAULT_RECIPE
    end
  end

  def self.run_install(recipe, params)
    with(params).reduce(recipe)
  end

  def self.call(cluster, user)
    connection = K8::Connection.new(cluster, user)
    kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))
    recipe = self.recipe(cluster, user)
    result = self.run_install(recipe, { cluster:, user:, kubectl:, connection: })
    cluster.running! if result.success?
    cluster.failed! if result.failure?
    result
  rescue StandardError => e
    cluster.failed!
    raise e
  end
end
