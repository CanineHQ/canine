class Projects::DestroyJob < ApplicationJob
  def perform(project)
    project.destroying!
    kubeconfig = project.cluster.kubeconfig
    kubectl = K8::Kubectl.new(kubeconfig)

    kubectl.call("delete namespace #{project.name}")

    # Delete the github webhook for the project IF there are no more projects that refer to that repository
    unless Project.where(repository_url: project.repository_url).where.not(id: project.id).exists?
      remove_github_webhook(project)
    end
    project.destroy!
  end

  def remove_github_webhook(project)
    client = Github::Client.new(project)
    client.remove_hook!
  rescue Octokit::NotFound
    # If the hook is not found, do nothing
  end
end
