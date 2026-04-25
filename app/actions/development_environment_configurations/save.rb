# frozen_string_literal: true

module DevelopmentEnvironmentConfigurations
  class Save
    extend LightService::Action

    expects :development_environment_configuration, :user

    executed do |context|
      development_environment_configuration = context.development_environment_configuration
      user = context.user

      validate_provider_ownership!(context, development_environment_configuration.git_provider_id, :git_provider_id, user)
      next if context.failure?

      unless development_environment_configuration.save
        context.fail!(development_environment_configuration.errors.full_messages.join(", "))
      end
    end

    private

    def self.validate_provider_ownership!(context, provider_id, field, user)
      return if provider_id.blank?
      return if user.providers.exists?(id: provider_id)

      context.development_environment_configuration.errors.add(field, "must belong to your user")
      context.fail!(context.development_environment_configuration.errors.full_messages.join(", "))
    end
  end
end
