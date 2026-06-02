class Onboarding::CreateUserWithAccount
  extend LightService::Action
  expects :account_name, :email, :password
  promises :user, :account

  executed do |context|
    ActiveRecord::Base.transaction do
      context.user = User.find_or_initialize_by(email: context.email)
      context.user.assign_attributes(
        password: context.password,
        password_confirmation: context.password,
      )
      context.user.write_attribute(:admin, true) if context.user.new_record?
      context.user.save!

      context.account = Account.create!(owner: context.user, name: context.account_name)
      AccountUser.create!(account: context.account, user: context.user, role: :owner)
    end
  rescue ActiveRecord::RecordInvalid => e
    context.fail_and_return!(e.message)
  end
end
