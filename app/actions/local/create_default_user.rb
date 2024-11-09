class Local::CreateDefaultUser
  extend LightService::Action

  promises :user, :account

  executed do |context|
    ActiveRecord::Base.transaction do
      context.user = User.first || User.new
      context.user.email = "#{ENV.fetch("USERNAME", SecureRandom.uuid)}@example.com"
      context.user.password = ENV.fetch("PASSWORD", "password")
      context.user.password_confirmation = ENV.fetch("PASSWORD", "password")
      context.user.save!
      context.account = context.user.accounts.first || context.user.accounts.create!(name: "Default")
      AccountUser.find_or_create_by!(account: context.account, user: context.user)
    end
  end
end