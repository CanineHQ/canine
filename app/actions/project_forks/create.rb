class ProjectForks::Create
  extend LightService::Organizer

  def self.call(parent_project:, pull_request:)
    with(parent_project:, pull_request:).reduce(
      ProjectForks::ForkProject,
      ProjectForks::InitializeFromCanineConfig
    )
  end
end
