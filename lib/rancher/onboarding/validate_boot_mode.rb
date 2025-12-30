# frozen_string_literal: true

class Rancher::Onboarding::ValidateBootMode
  extend LightService::Action

  executed do |context|
    if Rails.application.config.cloud_mode
      context.fail_and_return!("Rancher onboarding is not available in cloud mode")
    end
  end
end
