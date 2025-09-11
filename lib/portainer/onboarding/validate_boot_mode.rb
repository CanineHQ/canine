class Portainer::Onboarding::ValidateBootMode
  extend LightService::Action

  executed do |context|
    if Rails.application.config.cloud_mode
      context.fail_with_rollback!("Portainer onboarding is not available in cloud mode")
    end
    if Rails.application.config.default_stack_manager.blank?
      context.fail_with_rollback!("No default stack manager is configured")
    end
  end
end
