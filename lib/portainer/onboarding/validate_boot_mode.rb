class Portainer::Onboarding::ValidateBootMode
  extend LightService::Action

  executed do |context|
    if Rails.application.config.cloud_mode
      context.fail_with_rollback!("Portainer onboarding is not available in cloud mode")
    end
  end
end
