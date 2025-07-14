class CleanupClosedPrProjectsJob < ApplicationJob
  queue_as :default

  def perform
    ProjectFork.includes(:child_project, :parent_project).find_each do |project_fork|
      begin
        parent_project = project_fork.parent_project
        client = Git::Client.from_project(parent_project)

        pr_status = client.pull_request_status(project_fork.number.to_i)

        if pr_status == 'closed' || pr_status == 'merged' || pr_status == 'not_found'
          Rails.logger.info "Deleting child project #{project_fork.child_project.id} for closed PR ##{project_fork.number}"
          project_fork.child_project.destroy
        end
      rescue => e
        Rails.logger.error "Error checking PR status for project fork #{project_fork.id}: #{e.message}"
      end
    end
  end
end
