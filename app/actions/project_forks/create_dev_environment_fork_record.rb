class ProjectForks::CreateDevEnvironmentForkRecord
  extend LightService::Action

  expects :parent_project, :project
  promises :project_fork

  executed do |context|
    context.project_fork = ProjectFork.create!(
      child_project: context.project,
      parent_project: context.parent_project,
      fork_type: :dev_environment
    )
  end
end
