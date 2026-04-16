# frozen_string_literal: true

module DevelopmentEnvironmentConfigurations
  class Save
    extend LightService::Action

    expects :configuration, :user

    executed do |context|
      configuration = context.configuration
      user = context.user

      validate_provider_ownership!(context, configuration.git_provider_id, :git_provider_id, user)
      validate_provider_ownership!(context, configuration.llm_provider_id, :llm_provider_id, user)
      next if context.failure?

      unless configuration.save
        context.fail!(configuration.errors.full_messages.join(", "))
      end
    end

    private

    def self.validate_provider_ownership!(context, provider_id, field, user)
      return if provider_id.blank?
      return if user.providers.exists?(id: provider_id)

      context.configuration.errors.add(field, "must belong to your user")
      context.fail!(context.configuration.errors.full_messages.join(", "))
    end
  end
end
