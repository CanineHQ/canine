# frozen_string_literal: true

module SSO
  class CreateUserInAccount
    extend LightService::Action
    expects :email, :account, :sso_provider, :uid
    expects :name, default: nil
    promises :user

    executed do |context|
      # First try to find user by SSO provider identity
      provider = Provider.find_by(sso_provider: context.sso_provider, uid: context.uid)

      if provider
        user = provider.user
      else
        # Fall back to finding by email, or create new user
        user = User.find_or_initialize_by(email: context.email.downcase)

        if user.new_record?
          password = SecureRandom.hex(32)
          user.password = password
          user.password_confirmation = password

          unless user.save
            context.fail_and_return!("Failed to create user", errors: user.errors)
          end
        end

        # Create provider record to link user to SSO provider
        Provider.create!(
          user: user,
          sso_provider: context.sso_provider,
          uid: context.uid,
          provider: context.sso_provider.name
        )
      end

      # Update name from SSO provider on every login
      if context.name.present?
        name_parts = context.name.split(" ", 2)
        user.update(first_name: name_parts.first, last_name: name_parts.second)
      end

      AccountUser.find_or_create_by!(account: context.account, user: user)

      context.user = user
    end
  end
end
