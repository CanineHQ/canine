# frozen_string_literal: true

module DevelopmentEnvironmentConfigurations
  class Save
    extend LightService::Action

    expects :development_environment_configuration

    executed do |context|
      development_environment_configuration = context.development_environment_configuration

      unless development_environment_configuration.save
        context.fail!(development_environment_configuration.errors.full_messages.join(", "))
      end
    end
  end
end
