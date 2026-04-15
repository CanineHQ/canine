class ProjectForks::CreateDevEnvironment
  extend LightService::Organizer

  def self.call(parent_project:)
    dev_config = parent_project.development_environment_configuration
    target_cluster = dev_config&.cluster || parent_project.cluster

    with(
      parent_project:,
      target_cluster:
    ).reduce(
      ProjectForks::CreateDevEnvironmentDefinition,
      CanineConfig::RestoreProject,
      ProjectForks::CreateDevEnvironmentForkRecord,
      CanineConfig::Initialize
    )
  end
end
