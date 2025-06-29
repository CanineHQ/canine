class ProjectForks::Create
  extend LightService::Action

  expects :parent_project, :pull_request
  promises :project_fork

  executed do |context|
    parent_project = context.parent_project
    pull_request = context.pull_request
    child_project = parent_project.dup
    child_project.branch = pull_request.branch
    child_project.name = "#{parent_project.name}-#{pull_request.number}"
    # Duplicate the project_credential_provider
    child_project_credential_provider = parent_project.project_credential_provider.dup
    child_project_credential_provider.project = child_project

    # Duplicate the services
    new_services = parent_project.services.map do |service|
      new_service = service.dup
      new_service.allow_public_networking = false
      new_service.project = child_project
      new_service
    end

    ActiveRecord::Base.transaction do
      context.project_fork = ProjectFork.new(
        child_project:,
        parent_project:,
        external_id: pull_request.id,
        number: pull_request.number,
        title: pull_request.title,
        url: pull_request.url,
        user: pull_request.user,
      )
      child_project.save!
      child_project_credential_provider.save!
      new_services.each(&:save!)
      context.project_fork.save!
    end
  rescue StandardError => e
    context.fail_and_return!("Failed to create project fork: #{e.message}")
  end
end
