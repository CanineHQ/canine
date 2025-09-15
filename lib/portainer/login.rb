class Portainer::Login
  extend LightService::Action

  expects :username, :password, :account
  promises :user, :account

  executed do |context|
    provider_url = context.account.stack_manager.provider_url
    jwt = Portainer::Client.authenticate(
      username: context.username,
      auth_code: context.password,
      provider_url: provider_url
    )
    user = User.find_or_initialize_by(
      email: context.username + "@oncanine.run",
    )
    password = Devise.friendly_token
    user.assign_attributes(
      password:,
      password_confirmation: password,
    )
    user.save!
    provider = user.providers.find_or_initialize_by(provider: "portainer")
    provider.assign_attributes(access_token: jwt)
    provider.save!
    context.user = user

    unless account.users.include?(user)
      account.account_users.create!(user: result.user)
    end
  end
end