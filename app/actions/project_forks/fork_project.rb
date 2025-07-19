class ProjectForks::ForkProject
  extend LightService::Action

  expects :parent_project, :pull_request
  promises :project_fork

  executed do |context|
    parent_project = context.parent_project
    pull_request = context.pull_request
    child_project = parent_project.dup
    child_project.branch = pull_request.branch
    child_project.name = "#{parent_project.name}-#{pull_request.number}"
    child_project.cluster_id = parent_project.project_fork_cluster_id
    # Duplicate the project_credential_provider
    child_project_credential_provider = parent_project.project_credential_provider.dup
    child_project_credential_provider.project = child_project

    # Duplicate the services
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

      # Fetch and store canine config if it exists
      client = Git::Client.from_project(child_project)
      file = client.get_file('.canine.yml', pull_request.branch)
      if file.nil?
        file = client.get_file('.canine.yml.erb', pull_request.branch)
      end

      if file.present?
        # Parse and store the config
        canine_config = CanineConfig::Definition.parse(file.content, parent_project, pull_request)
        child_project.canine_config = canine_config.to_hash
        child_project.predeploy_command = canine_config.predeploy_command
        child_project.postdeploy_command = canine_config.postdeploy_command
        child_project.predestroy_command = canine_config.predestroy_command
        child_project.postdestroy_command = canine_config.postdestroy_command
      end
      context.project_fork.save!
    end
  rescue StandardError => e
    context.fail_and_return!("Failed to create project fork: #{e.message}")
  end
end
