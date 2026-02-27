class ClusterMigrations::MigrateProject
  extend LightService::Organizer

  def self.call(source_project:, target_cluster:, custom_name: nil, custom_namespace: nil, managed_namespace: false)
    with(source_project:, target_cluster:, custom_name:, custom_namespace:, managed_namespace:).reduce(
      CanineConfig::CreateDefinition,
      CanineConfig::RestoreProject,
      CanineConfig::Initialize
    )
  end
end
