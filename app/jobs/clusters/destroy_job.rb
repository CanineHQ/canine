class Clusters::DestroyJob < ApplicationJob
  queue_as :default

  def perform(cluster, user)
    cluster.destroying!
    cluster.projects.each do |project|
      Projects::DestroyJob.perform_now(project, user)
    end
    revoke_service_account(cluster, user)
    cluster.destroy!
  end

  private

  # The cluster may already be gone, so failing to reach it must not block the delete.
  def revoke_service_account(cluster, user)
    return unless cluster.manager_service_account?

    K8::ManagerServiceAccount.new(cluster.service_account_name).connect(K8::Connection.new(cluster, user)).uninstall!
  rescue StandardError => e
    Rails.logger.warn("Could not revoke Canine's access to #{cluster.name}: #{e.class} - #{e.message}")
  end
end
