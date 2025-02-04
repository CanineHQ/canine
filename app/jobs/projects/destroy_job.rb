class Projects::DestroyJob < ApplicationJob
  def perform(project)
    project.destroying!
    client = K8::Client.from_cluster(project.cluster)
    if (namespace = client.get_namespaces.find { |n| n.metadata.name == project.name }).present?
      client.delete_namespace(namespace.metadata.name)
    end

    # Delete the github webhook for the project IF there are no more projects that refer to that repository
    unless Project.where(repository_url: project.repository_url).where.not(id: project.id).exists?
      remove_github_webhook(project)
    end
    project.destroy!
  end

  def remove_github_webhook(project)
    client = Github::Client.new(project)
    client.remove_webhook!
  rescue Octokit::NotFound
    # If the hook is not found, do nothing
  end
end
