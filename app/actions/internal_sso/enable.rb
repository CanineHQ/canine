class InternalSSO::Enable
  extend LightService::Action

  expects :protectable

  executed do |context|
    protectable = context.protectable

    next context if protectable.oauth_application.present?

    protectable.create_oauth_application!(
      name: "Auth Proxy: #{protectable.name}",
      redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
      scopes: "openid profile email",
      confidential: true
    )
  end
end
