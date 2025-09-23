class Portainer::Login
  extend LightService::Action

  expects :username, :password, :account
  promises :user, :account

  executed do |context|
    provider_url = context.account.stack_manager.provider_url
    context.user = User.find_or_initialize_by(
      email: context.username + "@oncanine.run",
    )
    portainer_user = Portainer::Client.authenticate(
      username: context.username,
      auth_code: context.password,
      provider_url: provider_url
    )

    password = Devise.friendly_token
    context.user.assign_attributes(
      password:,
      password_confirmation: password,
    )
    context.user.save!
    provider = context.user.providers.find_or_initialize_by(provider: "portainer")
    provider.auth = {
      info: {
        username: portainer_user.username
      }
    }.to_json
    provider.access_token: portainer_user.jwt
    provider.save!

    unless context.account.users.include?(context.user)
      context.account.account_users.create!(user: context.user)
    end
  rescue Portainer::Client::AuthenticationError => e
    context.user.errors.add(:base, "Invalid username or password")
    context.fail_and_return!
  rescue Portainer::Client::ConnectionError => e
    context.fail_and_return!(e.message)
  rescue StandardError => e
    context.user ||= User.new(email: context.username)
    context.fail_and_return!("Authentication failed: #{e.message}")
  end
end
