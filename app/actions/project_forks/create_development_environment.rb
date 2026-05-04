class ProjectForks::CreateDevelopmentEnvironment
  extend LightService::Organizer

  def self.call(parent_project:, current_user:)
    development_environment_configuration = parent_project.development_environment_configuration
    target_cluster = development_environment_configuration&.cluster || parent_project.cluster

    with(
      parent_project:,
      current_user:,
      target_cluster:
    ).reduce(
      ProjectForks::CreateDevelopmentEnvironmentDefinition,
      CanineConfig::RestoreProject,
      ProjectForks::CreateDevelopmentEnvironmentRecord,
      CanineConfig::Initialize
    )
  end
end
