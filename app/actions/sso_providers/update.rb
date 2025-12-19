# frozen_string_literal: true

module SSOProviders
  class Update
    extend LightService::Organizer

    def self.call(sso_provider:, sso_provider_params:, configuration_params:)
      sso_provider.assign_attributes(sso_provider_params)

      with(
        sso_provider: sso_provider,
        configuration_params: configuration_params
      ).reduce(
        SSOProviders::UpdateConfiguration
      )
    end
  end
end
