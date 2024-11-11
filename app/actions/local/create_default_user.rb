class Local::CreateDefaultUser
  extend LightService::Action

  promises :user, :account

  executed do |context|
    ActiveRecord::Base.transaction do
      context.user = User.first || User.new
      context.user.email = "#{ENV.fetch("CANINE_USERNAME", SecureRandom.uuid)}@example.com"
      context.user.password = ENV.fetch("CANINE_PASSWORD", "password")
      context.user.password_confirmation = ENV.fetch("CANINE_PASSWORD", "password")
      context.user.save!
      context.account = context.user.accounts.first || Account.create!(name: "Default", owner: context.user)
      context.account.account_users.find_or_create_by!(user: context.user)
    end
  end
end
