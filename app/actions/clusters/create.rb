class Clusters::Create
  extend LightService::Organizer

  def self.call(cluster)
    with(cluster:).reduce(
      Clusters::ValidateKubeConfig,
      Clusters::Save,
    )
  end
end