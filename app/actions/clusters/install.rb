class Clusters::Install
  DEFAULT_NAMESPACE = "canine-system".freeze
  extend LightService::Organizer

  def self.call(cluster)
    cluster.installing!
    result = with(cluster:).reduce(
      Clusters::IsReady,
      Clusters::CreateNamespace,
      Clusters::InstallNginxIngress,
      Clusters::InstallAcmeIssuer,
      Clusters::InstallMetricServer,
    )
    cluster.running! if result.success?
    cluster.failed! if result.failure?
  rescue StandardError => e
    cluster.failed!
    raise e
  end
end