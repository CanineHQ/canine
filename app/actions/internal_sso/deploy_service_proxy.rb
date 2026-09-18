class InternalSSO::DeployServiceProxy
  extend LightService::Action

  expects :service

  executed do |context|
    service = context.service

    next context unless service.internal? && service.primary_domain.present?

    service.oauth_application.update!(
      redirect_uri: "https://#{service.primary_domain}/oauth2/callback"
    )
  end
end
