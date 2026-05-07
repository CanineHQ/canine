class ProjectForks::CreateDevelopmentEnvironment
  extend LightService::Organizer

  def self.call(parent_project:, current_user:, git_provider:)
    development_environment_configuration = parent_project.development_environment_configuration
    raise "No development environment configuration found for project #{parent_project.id}" unless development_environment_configuration

    with(
      parent_project:,
      current_user:,
      git_provider:,
      target_cluster: development_environment_configuration.cluster
    ).reduce(
      ProjectForks::CreateDevelopmentEnvironmentDefinition,
      CanineConfig::RestoreProject,
      ProjectForks::CreateDevelopmentEnvironmentRecord,
      CanineConfig::Initialize
    )
  end
end
