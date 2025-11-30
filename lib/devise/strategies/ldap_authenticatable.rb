require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class LDAPAuthenticatable < Authenticatable
      def valid?
        puts "Validating ldap authenticatable"
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
            # Determine the groups
            groups = get_group_information(ldap, user_dn)
            ActiveRecord::Base.transaction do
              user = User.find_or_create_by!(email: email) do |user|
                password = SecureRandom.hex(32)
                user.password = password
                user.password_confirmation = password
              end
              AccountUser.find_or_create_by!(account: ldap_configuration.account, user:)
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
        account = Account.friendly.find(params[:slug])
        unless account.sso_enabled?
          raise "SSO is not enabled for this account"
        end

        sso_provider = account.sso_provider
        unless sso_provider.ldap?
          raise "Account does not support LDAP authentication"
        end
        sso_provider.configuration
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

      def get_group_information(ldap, user_dn)
        debugger
        # ldap.search(base: "ou=Groups,dc=example,dc=org", filter: Net::LDAP::Filter.eq("memberUid", user_dn))
        [
          {
            name: "developers"
          },
          {
            name: "administrators"
          }
        ]
      end

      def find_or_create_account_for_ldap(ldap_config)
        sso_provider = ldap_config.sso_provider
        sso_provider&.account
      end
    end
  end
end
