# frozen_string_literal: true

module SSOProviders
  class SaveConfiguration
    extend LightService::Action
    expects :sso_provider, :configuration

    executed do |context|
      context.sso_provider.configuration = context.configuration

      unless context.configuration.save
        context.fail_and_return!("Failed to save configuration", errors: context.configuration.errors)
      end

      unless context.sso_provider.save
        context.fail_and_return!("Failed to save SSO provider", errors: context.sso_provider.errors)
      end
    end
  end
end
