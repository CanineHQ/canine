# frozen_string_literal: true

module SSOProviders
  class BuildSSOConfiguration
    extend LightService::Action
    expects :provider_type, :configuration_params
    promises :configuration

    executed do |context|
      context.configuration = case context.provider_type
      when "ldap"
        LDAPConfiguration.new(context.configuration_params)
      when "oidc"
        OIDCConfiguration.new(context.configuration_params)
      when "saml"
        SAMLConfiguration.new(context.configuration_params)
      else
        context.fail_and_return!("Unknown provider type: #{context.provider_type}")
      end
    end
  end
end
