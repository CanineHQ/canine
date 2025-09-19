class Portainer::Login
  extend LightService::Action

  expects :username, :password, :account
  promises :user, :account

  executed do |context|
    provider_url = context.account.stack_manager.provider_url
    context.user = User.find_or_initialize_by(
      email: context.username + "@oncanine.run",
    )
    context.user.errors.add(:base, "Invalid username or password")
    jwt = Portainer::Client.authenticate(
      username: context.username,
      auth_code: context.password,
      provider_url: provider_url
    )

    if jwt.nil?
      context.user.errors.add(:base, "Invalid username or password")
      context.fail_and_return!
    end

    password = Devise.friendly_token
    context.user.assign_attributes(
      password:,
      password_confirmation: password,
    )
    context.user.save!
    provider = context.user.providers.find_or_initialize_by(provider: "portainer")
    provider.assign_attributes(access_token: jwt)
    provider.save!

    unless context.account.users.include?(context.user)
      context.account.account_users.create!(user: context.user)
    end
  rescue StandardError => e
    context.user ||= User.new(email: context.username)
    context.user.errors.add(:base, "Authentication failed: #{e.message}")
    context.fail_and_return!
  end
end