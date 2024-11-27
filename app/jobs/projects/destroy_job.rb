class Projects::DestroyJob < ApplicationJob
  def perform(project)
    project.destroying!
    kubeconfig = project.cluster.kubeconfig
    kubectl = K8::Kubectl.new(kubeconfig)

    kubectl.call("delete namespace #{project.name}")
    # Delete the github webhook for the project IF there are no more projects that refer to that repository

    unless Project.where(repository_url: project.repository_url).where.not(id: project.id).exists?
      client = Octokit::Client.new(access_token: project.account.github_access_token)

      # Get all webhooks for the repository
      hooks = client.hooks(project.repository_url)

      # Find the webhook with matching URL
      hook = hooks.find { |h| h.config.url.include?(Rails.application.routes.url_helpers.inbound_webhooks_github_index_path) }

      # Delete the hook if found
      client.remove_hook(project.repository_url, hook.id) if hook
    end
    project.events.destroy_all
    project.builds.each do |build|
      build.deployment.destroy!
      build.destroy!
    end
    project.destroy!
  end
end
