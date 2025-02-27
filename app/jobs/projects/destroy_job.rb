class Projects::DestroyJob < ApplicationJob
  def perform(project)
    project.destroying!
    delete_namespace(project)

    # Delete the github webhook for the project IF there are no more projects that refer to that repository
    # TODO: This might have overlapping repository urls across different providers.
    # Need to check for provider uniqueness
    unless Project.where(
      repository_url: project.repository_url,
    ).where.not(id: project.id).exists?
      remove_github_webhook(project)
    end
    project.destroy!
  end

  def delete_namespace(project)
    client = K8::Client.from_cluster(project.cluster)
    if (namespace = client.get_namespaces.find { |n| n.metadata.name == project.name }).present?
      client.delete_namespace(namespace.metadata.name)
    end
  end

  def remove_github_webhook(project)
    client = Github::Client.from_project(project)
    client.remove_webhook!
  rescue Octokit::NotFound
    # If the hook is not found, do nothing
  end
end
