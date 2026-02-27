class ClusterMigrations::MigrateProject
  extend LightService::Organizer

  def self.call(source_project:, target_cluster:)
    with(source_project:, target_cluster:).reduce(
      CanineConfig::CreateDefinition,
      CanineConfig::RestoreProject,
      CanineConfig::Initialize
    )
  end
end
