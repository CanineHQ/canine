class InternalSSO::Disable
  extend LightService::Action

  expects :protectable

  executed do |context|
    protectable = context.protectable

    next context unless protectable.oauth_application.present?

    protectable.oauth_application.destroy
  end
end
