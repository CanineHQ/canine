class Portainer::SyncClusters
  extend LightService::Action

  expects :stack_manager, :user

  executed do |context|
    context.stack_manager.connect(context.user).sync_clusters
  end
end