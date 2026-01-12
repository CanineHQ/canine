class StackManagers::Create
  extend LightService::Action
  expects :account, :user, :stack_manager_params, :personal_access_token
  promises :stack_manager

  executed do |context|
    ActiveRecord::Base.transaction do
      context.stack_manager = context.account.stack_manager || context.account.build_stack_manager
      context.stack_manager.assign_attributes(context.stack_manager_params)
      context.stack_manager.save!

      portainer_access_token = context.personal_access_token.presence || context.stack_manager.access_token
      provider = context.user.providers.find_or_initialize_by(provider: Provider::PORTAINER_PROVIDER)
      provider.access_token = portainer_access_token
      provider.save!
    end
  end
end
