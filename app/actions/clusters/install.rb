class Clusters::Install
  DEFAULT_NAMESPACE = "canine-system".freeze
  extend LightService::Organizer

  def self.call(cluster, user)
    connection = K8::Connection.new(cluster, user)
    kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))
    result = with(cluster:, user:, kubectl:, connection:).reduce(
      Clusters::IsReady,
      Clusters::CreateNamespace,
      Clusters::InstallNginxIngress,
      Clusters::InstallAcmeIssuer,
      Clusters::InstallMetricServer,
      Clusters::InstallTelepresence,
    )
    cluster.running! if result.success?
    cluster.failed! if result.failure?
  rescue StandardError => e
    cluster.failed!
    raise e
  end
end
