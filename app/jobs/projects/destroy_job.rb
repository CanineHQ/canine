class Projects::DestroyJob < ApplicationJob
  UNINSTALL_RETRIES = 3
  UNINSTALL_RETRY_INTERVAL = 5

  def perform(project, user)
    project.destroying!

    DevelopmentEnvironments::Destroy.execute(project:)

    uninstall_with_retries(project, user)

    cleanup_auto_managed_domains(project)
    remove_github_webhook(project) if should_remove_webhook?(project)
    project.destroy!
  end

  private

  def uninstall_with_retries(project, user)
    attempts = 0
    begin
      attempts += 1
      uninstall_service_class(project).new(project, user).call
    rescue Cli::CommandFailedError => e
      if attempts < UNINSTALL_RETRIES
        Rails.logger.warn("Uninstall attempt #{attempts}/#{UNINSTALL_RETRIES} failed for '#{project.name}': #{e.message}. Retrying in #{attempts * 5}s...")
        sleep(attempts * UNINSTALL_RETRY_INTERVAL)
        retry
      end
      Rails.logger.error("Uninstall failed after #{UNINSTALL_RETRIES} attempts for '#{project.name}': #{e.message}. Continuing with destroy.")
    end
  end

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

  def cleanup_auto_managed_domains(project)
    project.domains.where(auto_managed: true).find_each do |domain|
      Domains::Destroy.cleanup_dns_record(domain)
    end
  end
end
