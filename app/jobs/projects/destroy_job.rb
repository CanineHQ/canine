class Projects::DestroyJob < ApplicationJob
  def perform(project, user)
    project.destroying!
    delete_namespace(project, user)

    # Delete the github webhook for the project IF there are no more projects that refer to that repository
    # TODO: This might have overlapping repository urls across different providers.
    # Need to check for provider uniqueness
    if project.github? && Project.where(
      repository_url: project.repository_url).where.not(id: project.id).empty?
      remove_github_webhook(project)
    end
    project.destroy!
  end

  def delete_namespace(project, user)
    client = K8::Client.new(K8::Connection.new(project.cluster, user))
    if (namespace = client.get_namespaces.find { |n| n.metadata.name == project.name }).present?
      client.delete_namespace(namespace.metadata.name)
    end
  end

  def remove_github_webhook(project)
    client = Git::Client.from_project(project)
    client.remove_webhook!
  rescue Octokit::NotFound
    # If the hook is not found, do nothing
  end
end
