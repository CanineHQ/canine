# app/strategies/devise/ldap_authenticatable.rb
require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class LDAPAuthenticatable < Authenticatable
      def valid?
        # basic shape check
        user_params = params[:user]
        return false unless user_params.is_a?(ActionController::Parameters) || user_params.is_a?(Hash)

        username = user_params[:username].presence
        password = user_params[:password].presence

        return false if username.blank? || password.blank?

        # make sure this slug maps to an LDAP-enabled account
        begin
          account = Account.friendly.find(params[:slug])

          return false unless account&.sso_enabled?
          sso_provider = account.sso_provider
          return false unless sso_provider&.ldap?
        rescue ActiveRecord::RecordNotFound
          # bad slug → this strategy is not applicable
          return false
        end

        true
      end

      def authenticate!
        return unless params[:user]

        ldap_configuration = find_ldap_configuration
        return fail(:invalid_login) unless ldap_configuration

        authenticator = LDAP::Authenticator.new(ldap_configuration)

        sso_provider = ldap_configuration.sso_provider
        result = authenticator.call(
          username: username,
          password: password,
          fetch_groups: sso_provider.just_in_time_team_provisioning_mode?
        )

        unless result.success?
          Rails.logger.info "LDAP auth failed for username=#{username.inspect}: #{result.error_message}"
          return fail(:invalid_login)
        end

        email = result.email

        if sso_provider.just_in_time_team_provisioning_mode?
          groups = result.groups
          ar_result = ActiveRecord::Base.transaction do
            SSO::SyncUserTeams.call(email, groups, ldap_configuration.account)
          end
        else
          ar_result = SSO::CreateUserInAccount.execute(
            email: email,
            account: ldap_configuration.account,
          )
        end

        if ar_result.failure?
          return fail(:invalid_login)
        end

        success!(ar_result.user)
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "LDAP auth: account not found - #{e.message}"
        fail(:invalid_login)
      rescue => e
        Rails.logger.error "LDAP auth: unexpected error in Devise strategy - #{e.class}: #{e.message}"
        fail(:invalid_login)
      end

      def username
        params[:user][:username]
      end

      def password
        params[:user][:password]
      end

      private

      def find_ldap_configuration
        account = Account.friendly.find(params[:slug])
        unless account.sso_enabled?
          raise 'SSO is not enabled for this account'
        end

        sso_provider = account.sso_provider
        unless sso_provider.ldap?
          raise 'Account does not support LDAP authentication'
        end

        sso_provider.configuration
      end
    end
  end
end
