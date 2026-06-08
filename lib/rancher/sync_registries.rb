class Rancher::SyncRegistries
  extend LightService::Action

  expects :stack_manager, :user, :clusters

  executed do |context|
    # Rancher does not provide a centralized registry API.
    # Registry credentials are managed as Kubernetes secrets per namespace.
    context
  end
end
