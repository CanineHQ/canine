class Portainer::SyncRegistries
  extend LightService::Action

  expects :stack_manager, :user

  executed do |context|
    context.stack_manager.connect(context.user).sync_registries
  end
end
