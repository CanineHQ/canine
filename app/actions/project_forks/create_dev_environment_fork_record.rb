class ProjectForks::CreateDevEnvironmentForkRecord
  extend LightService::Action

  expects :parent_project, :project
  promises :dev_environment_fork

  executed do |context|
    context.dev_environment_fork = DevEnvironmentFork.create!(
      child_project: context.project,
      parent_project: context.parent_project
    )
  end
end
