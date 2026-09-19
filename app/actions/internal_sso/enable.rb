class InternalSSO::Enable
  extend LightService::Action

  expects :protectable

  executed do |context|
    protectable = context.protectable

    next context if protectable.oauth_application.present?

    app_host = ENV.fetch("APP_HOST")
    app_host = "https://#{app_host}" unless app_host.start_with?("http")

    protectable.create_oauth_application!(
      name: "Auth Proxy: #{protectable.name}",
      redirect_uri: "#{app_host}/oauth2/callback",
      scopes: "openid profile email",
      confidential: true
    )
  end
end
