class Local::CreateDefaultUser
  BASE_DOMAIN = "oncanine.run"
  extend LightService::Action

  promises :user, :account

  executed do |context|
    ActiveRecord::Base.transaction do
      context.user = User.first || User.new(
        email: "#{ENV["CANINE_USERNAME"].presence || SecureRandom.uuid}@#{BASE_DOMAIN}",
        password: ENV["CANINE_PASSWORD"].presence || "password",
        password_confirmation: ENV["CANINE_PASSWORD"].presence || "password",
        admin: true
      )
      context.user.save!
      context.account = context.user.accounts.first || Account.create!(name: "Default", owner: context.user)
      context.account.account_users.find_or_create_by!(user: context.user)
    end
  end
end
