class Clusters::Create
  extend LightService::Organizer

  def self.call(cluster, user)
    with(cluster:, user:).reduce(
      Clusters::ValidateKubeConfig,
      Clusters::Save,
    )
  end
end
