# frozen_string_literal: true

module SSOProviders
  class UpdateConfiguration
    extend LightService::Action
    expects :sso_provider, :configuration_params

    executed do |context|
      configuration = context.sso_provider.configuration

      unless configuration.update(context.configuration_params)
        context.fail_and_return!("Failed to update configuration", errors: configuration.errors)
      end

      unless context.sso_provider.save
        context.fail_and_return!("Failed to save SSO provider", errors: context.sso_provider.errors)
      end
    end
  end
end
