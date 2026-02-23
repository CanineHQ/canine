class ProjectForks::PostForkComment
  extend LightService::Action
  expects :project_fork

  executed do |context|
    project_fork = context.project_fork
    ProjectForks::PostCommentJob.perform_later(project_fork)
  end
end
