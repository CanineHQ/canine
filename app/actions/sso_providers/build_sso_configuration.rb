# frozen_string_literal: true

module SSOProviders
  class BuildSSOConfiguration
    extend LightService::Action
    expects :provider_type, :configuration_params
    promises :configuration

    executed do |context|
      context.configuration = LDAPConfiguration.new(context.configuration_params)
    end
  end
end
