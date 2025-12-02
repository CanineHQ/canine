require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class LDAPAuthenticatable < Authenticatable
      def self.fetch_group_membership(ldap_configuration, user_dn)
        unless ldap_configuration.reader_dn.present? && ldap_configuration.reader_password.present?
          return []
        end

        reader_ldap = Net::LDAP.new(
          host: ldap_configuration.host,
          port: ldap_configuration.port,
          encryption: ldap_configuration.encryption_method,
          auth: {
            method: :simple,
            username: ldap_configuration.reader_dn,
            password: ldap_configuration.reader_password
          }
        )

        unless reader_ldap.bind
          Rails.logger.warn "LDAP reader bind failed: #{reader_ldap.get_operation_result.message}"
          return []
        end

        groups = []

        # Search for groups where the user is a member
        # Try both member (DN-based) and memberUid (username-based) attributes
        member_filter = Net::LDAP::Filter.eq("member", user_dn)
        member_uid_filter = Net::LDAP::Filter.eq("memberUid", user_dn.split(",").first.split("=").last)
        group_filter = Net::LDAP::Filter.eq("objectClass", "groupOfNames") |
                       Net::LDAP::Filter.eq("objectClass", "groupOfUniqueNames") |
                       Net::LDAP::Filter.eq("objectClass", "posixGroup")

        combined_filter = group_filter & (member_filter | member_uid_filter)

        reader_ldap.search(base: ldap_configuration.base_dn, filter: combined_filter) do |entry|
          groups << { name: entry.cn.first }
        end

        Rails.logger.info "Found #{groups.size} LDAP groups for user #{user_dn}"
        groups
      end

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
            groups = self.class.fetch_group_membership(ldap_configuration, user_dn)
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

      def find_or_create_account_for_ldap(ldap_config)
        sso_provider = ldap_config.sso_provider
        sso_provider&.account
      end
    end
  end
end
