require "omniauth_openid_connect"

module OmniAuth
  module Strategies
    class DynamicOIDC < OmniAuth::Strategies::OpenIDConnect
      option :name, "oidc"
      option :issuer, "placeholder"  # Will be overridden

      # Run before request_phase to load config from database
      def request_phase
        load_configuration_from_database
        super
      end

      # Run before callback_phase to load config from database
      def callback_phase
        load_configuration_from_database
        super
      end

      private

      def load_configuration_from_database
        sso_provider_id = request.params["sso_provider_id"] || session["sso_provider_id"]

        return unless sso_provider_id.present?

        begin
          sso_provider = SSOProvider.find_by(id: sso_provider_id, enabled: true)

          if sso_provider&.oidc? && sso_provider.configuration
            oidc_config = sso_provider.configuration

            # Override the options with database values
            options[:issuer] = oidc_config.issuer
            options[:client_options] = {
              identifier: oidc_config.client_id,
              secret: oidc_config.client_secret,
              redirect_uri: callback_url,
              authorization_endpoint: oidc_config.authorization_endpoint.presence,
              token_endpoint: oidc_config.token_endpoint.presence,
              userinfo_endpoint: oidc_config.userinfo_endpoint.presence,
              jwks_uri: oidc_config.jwks_uri.presence
            }.compact

            options[:scope] = oidc_config.scopes&.split(" ") || [ :openid, :email, :profile ]
            options[:response_type] = :code
            options[:uid_field] = "sub"

            # Store in session for callback
            session["sso_provider_id"] = sso_provider.id
            session["sso_account_id"] = sso_provider.account_id
          end
        rescue ActiveRecord::StatementInvalid, PG::UndefinedTable
          # Database not ready yet or table doesn't exist
          Rails.logger.debug "DynamicOIDC: database not ready"
        end
      end
    end
  end
end
