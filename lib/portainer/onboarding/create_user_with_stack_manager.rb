class Portainer::Onboarding::CreateUserWithStackManager
  extend LightService::Action
  expects :portainer_user, :username, :provider_url, :account_name
  promises :user, :account, :stack_manager

  executed do |context|
    password = Devise.friendly_token
    ActiveRecord::Base.transaction do
      context.user = User.find_or_initialize_by(
        email: context.username + "@oncanine.run",
      )
      context.user.assign_attributes(
        password:,
        password_confirmation: password,
      )
      if context.user.new_record?
        context.user.write_attribute(:admin, true)
      end
      context.user.save!

      provider = context.user.providers.find_or_initialize_by(provider: "portainer")
      provider.auth = {
        info: {
          username: context.portainer_user.username
        }
      }.to_json
      provider.access_token = context.portainer_user.jwt
      provider.save!

      if context.user.accounts.empty?
        context.account = Account.create!(owner: context.user, name: context.account_name)

        AccountUser.create!(account: context.account, user: context.user)
      else
        context.account = context.user.accounts.first
      end

      context.stack_manager = StackManager.find_or_initialize_by(
        account: context.account,
        stack_manager_type: :portainer,
        provider_url: context.provider_url
      )
      context.stack_manager.save!
    end
  end
end
