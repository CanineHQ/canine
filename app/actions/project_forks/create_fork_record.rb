class ProjectForks::CreateForkRecord
  extend LightService::Action

  expects :parent_project, :pull_request, :project
  promises :project_fork

  executed do |context|
    context.project_fork = ProjectFork.create!(
      child_project: context.project,
      parent_project: context.parent_project,
      external_id: context.pull_request.id,
      number: context.pull_request.number,
      title: context.pull_request.title,
      url: context.pull_request.url,
      user: context.pull_request.user
    )
  end
end
