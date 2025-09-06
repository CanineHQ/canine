class Portainer::Onboarding::InitializerPortainerAccount
  extend LightService::Action

  expects :account

  executed do |context|
    context.account.stack_manager.instance.sync_clusters
  end
end