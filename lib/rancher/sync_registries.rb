# frozen_string_literal: true

class Rancher::SyncRegistries
  extend LightService::Action

  expects :stack_manager, :user, :clusters

  executed do |context|
    # Rancher catalogs are Helm repositories, not container registries
    # Container registry credentials in Rancher are managed at the cluster level
    # This is a no-op for Rancher but maintains interface compatibility
    clusters = context.stack_manager.account.clusters
    if clusters.any?
      context.stack_manager.stack.connect(context.user).sync_registries(
        context.user,
        clusters.first
      )
    end
  end
end
