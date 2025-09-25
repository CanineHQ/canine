class Portainer::SyncRegistries
  extend LightService::Action

  expects :stack_manager, :user, :clusters

  executed do |context|
    clusters = context.stack_manager.account.clusters
    context.stack_manager.stack.connect(context.user).sync_registries(
      context.user,
      clusters.first
    )
  end
end
