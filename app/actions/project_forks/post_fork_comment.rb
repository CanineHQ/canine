class ProjectForks::PostForkComment
  extend LightService::Action
  expects :project_fork

  executed do |context|
    project_fork = context.project_fork
    parent_project = project_fork.parent_project

    next unless parent_project.project_fork_comment_enabled?

    client = Git::Client.from_project(parent_project)
    comment_body = build_comment_body(project_fork)
    client.add_pull_request_comment(project_fork.number, comment_body)
  rescue StandardError => e
    Rails.logger.error("Failed to post fork comment: #{e.message}")
    # Don't fail the entire workflow if comment posting fails
  end

  def self.build_comment_body(project_fork)
    project_url = Rails.application.routes.url_helpers.project_url(project_fork.child_project)

    <<~COMMENT
      🚀 **Preview environment created!**

      A preview environment has been created for this pull request.

      **Project:** [#{project_fork.child_project.name}](#{project_url})

      The deployment is in progress. Once complete, you'll be able to access the preview at the project link above.

      ---
      *Deployed by [Canine](#{Rails.application.routes.url_helpers.root_url})*
    COMMENT
  end
end
