class Portainer::SyncClusters
  extend LightService::Action

  expects :stack_manager, :user
  promises :clusters

  executed do |context|
    context.clusters = context.stack_manager.stack.connect(context.user).sync_clusters
  end
end
