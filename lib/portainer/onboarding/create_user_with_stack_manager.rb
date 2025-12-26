class Portainer::Onboarding::CreateUserWithStackManager
  extend LightService::Action
  expects :account_name, :provider_url, :access_token, :enable_role_based_access_control,
          :email, :password, :personal_access_token
  promises :user, :account, :stack_manager

  executed do |context|
    ActiveRecord::Base.transaction do
      context.user = User.find_or_initialize_by(
        email: context.email,
      )
      context.user.assign_attributes(
        password: context.password,
        password_confirmation: context.password,
      )
      if context.user.new_record?
        context.user.write_attribute(:admin, true)
      end
      context.user.save!

      portainer_access_token = context.personal_access_token.presence || context.access_token
      provider = context.user.providers.find_or_initialize_by(provider: Provider::PORTAINER_PROVIDER)
      provider.access_token = portainer_access_token
      provider.save!

      context.account = Account.create!(owner: context.user, name: context.account_name)

      AccountUser.create!(account: context.account, user: context.user, role: :owner)

      context.stack_manager = StackManager.find_or_initialize_by(
        account: context.account,
        stack_manager_type: :portainer,
        provider_url: context.provider_url,
        access_token: context.access_token,
        enable_role_based_access_control: context.enable_role_based_access_control,
      )
      context.stack_manager.save!
    end
  end
end
