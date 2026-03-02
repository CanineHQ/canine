class ProjectForks::Create
  extend LightService::Organizer

  def self.call(parent_project:, pull_request:)
    with(
      parent_project:,
      pull_request:,
      target_cluster: parent_project.project_fork_cluster
    ).reduce(
      ProjectForks::CreateDefinition,
      CanineConfig::RestoreProject,
      ProjectForks::CreateForkRecord,
      CanineConfig::Initialize
    )
  end
end
