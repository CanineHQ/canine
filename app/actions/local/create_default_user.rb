class Local::CreateDefaultUser
  extend LightService::Action

  promises :user, :account

  executed do |context|
    ActiveRecord::Base.transaction do
      context.user = User.first || User.new
      context.user.email = "#{ENV["CANINE_USERNAME"].presence || SecureRandom.uuid}@example.com"
      context.user.password = ENV["CANINE_PASSWORD"].presence || "password"
      context.user.password_confirmation = ENV["CANINE_PASSWORD"].presence || "password"
      context.user.save!
      context.account = context.user.accounts.first || Account.create!(name: "Default", owner: context.user)
      context.account.account_users.find_or_create_by!(user: context.user)
    end
  end
end
