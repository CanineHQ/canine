class ProjectForks::CreateDevelopmentEnvironmentRecord
  extend LightService::Action

  expects :parent_project, :project, :git_provider
  promises :development_environment

  executed do |context|
    context.development_environment = DevelopmentEnvironment.create!(
      child_project: context.project,
      parent_project: context.parent_project,
      git_provider: context.git_provider
    )
  end
end
