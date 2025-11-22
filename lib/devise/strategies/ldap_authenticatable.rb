require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class LDAPAuthenticatable < Authenticatable
      def valid?
        true
      end

      def authenticate!
        if params[:user]
          ldap_configuration = find_ldap_configuration

          return fail(:invalid_login) unless ldap_configuration

          ldap = Net::LDAP.new(
            host: ldap_configuration.host,
            port: ldap_configuration.port,
            encryption: ldap_configuration.encryption_method
          )

          # Build the user DN for authentication
          user_dn = build_user_dn(ldap_configuration, username)
          ldap.auth user_dn, password

          if ldap.bind
            # LDAP authentication successful, find or create user
            email = construct_email(username, ldap_configuration)
            user = User.find_or_create_by(email: email) do |user|
              password = SecureRandom.hex(32)
              user.password = password
              user.password_confirmation = password

              AccountUser.create!(account: ldap_configuration.account, user:)
            end
            success!(user)
          else
            Rails.logger.info "LDAP bind failed for #{email}: #{ldap.get_operation_result.message}"
            fail(:invalid_login)
          end
        end
      end

      def username
        params[:user][:username]
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
        else
          raise "No account ID provided"
        end
      end

      def build_user_dn(ldap_config, username)
        # Build the DN using the uid attribute and base DN
        "#{ldap_config.uid_attribute}=#{username},#{ldap_config.base_dn}"
      end

      def construct_email(username, ldap_config)
        # If username is already an email, use it as-is
        return username if username.include?('@')
        
        # Otherwise, construct email using mail_domain from config if available
        domain = ldap_config.try(:mail_domain) || ldap_config.host
        "#{username}@#{domain}"
      end

      def find_or_create_account_for_ldap(ldap_config)
        sso_provider = ldap_config.sso_provider
        sso_provider&.account
      end
    end
  end
end
