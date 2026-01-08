class Projects::DestroyJob < ApplicationJob
  def perform(project, user)
    project.destroying!

    uninstall_service_class(project).new(project, user).call

    remove_github_webhook(project) if should_remove_webhook?(project)
    project.destroy!
  end

  private

  def uninstall_service_class(project)
    deployment_method = project.deployment_configuration&.deployment_method || "legacy"

    case deployment_method
    when "helm"
      Projects::HelmUninstallService
    else
      Projects::LegacyUninstallService
    end
  end

  def should_remove_webhook?(project)
    project.github? && Project.where(repository_url: project.repository_url).where.not(id: project.id).empty?
  end

  def remove_github_webhook(project)
    client = Git::Client.from_project(project)
    client.remove_webhook!
  rescue Octokit::NotFound
    # If the hook is not found, do nothing
  end
end
