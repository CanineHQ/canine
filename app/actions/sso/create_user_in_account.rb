# frozen_string_literal: true

module SSO
  class CreateUserInAccount
    extend LightService::Action
    expects :email, :account
    promises :user

    executed do |context|
      user = User.find_or_initialize_by(email: context.email.downcase)

      if user.new_record?
        password = SecureRandom.hex(32)
        user.password = password
        user.password_confirmation = password

        unless user.save
          context.fail_and_return!("Failed to create user", errors: user.errors)
        end
      end

      AccountUser.find_or_create_by!(account: context.account, user: user)

      context.user = user
    end
  end
end
