class Portainer::SyncRegistries
  extend LightService::Action

  expects :stack_manager, :user, :clusters

  executed do |context|
    context.stack_manager.stack.connect(context.user).sync_registries(
      context.user,
      context.clusters.first
    )
  end
end
