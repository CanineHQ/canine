# frozen_string_literal: true

module SSOProviders
  class Create
    extend LightService::Organizer

    def self.call(account:, sso_provider_params:, configuration_params:, provider_type:)
      sso_provider = account.build_sso_provider(sso_provider_params)

      with(
        sso_provider: sso_provider,
        provider_type: provider_type,
        configuration_params: configuration_params
      ).reduce(
        SSOProviders::BuildSSOConfiguration,
        SSOProviders::SaveConfiguration
      )
    end
  end
end
