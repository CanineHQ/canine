require 'net/ldap'
require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class LdapAuthenticatable < Authenticatable
      def authenticate!
        if params[:user]
          ldap_config = find_ldap_configuration

          return fail(:invalid_login) unless ldap_config

          ldap = Net::LDAP.new(
            host: ldap_config.host,
            port: ldap_config.port,
            encryption: ldap_config.encryption_method
          )

          # Build the user DN for authentication
          user_dn = build_user_dn(ldap_config, email)
          ldap.auth user_dn, password

          if ldap.bind
            # LDAP authentication successful, find or create user
            user = User.find_or_create_by(email: email) do |u|
              u.password = SecureRandom.hex(32) # Set random password since LDAP handles auth
              u.account = find_or_create_account_for_ldap(ldap_config)
            end
            success!(user)
          else
            Rails.logger.info "LDAP bind failed for #{email}: #{ldap.get_operation_result.message}"
            return fail(:invalid_login)
          end
        end
      end

      def email
        params[:user][:email]
      end

      def password
        params[:user][:password]
      end

      private

      def find_ldap_configuration
        # Find the LDAP configuration for the account
        # This could be based on email domain or a selection during login
        account_id = session[:ldap_account_id] || params[:account_id]

        if account_id
          sso_provider = SSOProvider.find_by(account_id: account_id, enabled: true)
          return sso_provider.configuration if sso_provider&.ldap?
        end

        # Fallback: try to find by email domain or return first enabled LDAP config
        LdapConfiguration.joins(:sso_provider)
                         .where(sso_providers: { enabled: true })
                         .first
      end

      def build_user_dn(ldap_config, email)
        # Extract username from email if needed
        username = email.split('@').first

        # Build the DN using the uid attribute and base DN
        "#{ldap_config.uid_attribute}=#{username},#{ldap_config.base_dn}"
      end

      def find_or_create_account_for_ldap(ldap_config)
        sso_provider = ldap_config.sso_provider
        sso_provider&.account
      end
    end
  end
end

Warden::Strategies.add(:ldap_authenticatable, Devise::Strategies::LdapAuthenticatable)
