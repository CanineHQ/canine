class ProjectForks::Create
  extend LightService::Organizer

  def self.call(parent_project:, pull_request:, current_user:)
    with(parent_project:, pull_request:).reduce(
      ProjectForks::ForkProject,
      ProjectForks::InitializeFromCanineConfig,
      execute(->(ctx) { ctx[:project] = ctx.project_fork.child_project }).
      Projects::DeployLatestCommit,
      ProjectForks::PostForkComment,
    )
  end
end
