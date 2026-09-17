class AddOns::ManageOauthApplication
  extend LightService::Action
  expects :add_on, :was_internal

  executed do |context|
    add_on = context.add_on

    if add_on.internal?
      unless add_on.oauth_application.present?
        add_on.create_oauth_application!(
          name: "Auth Proxy: #{add_on.name}",
          redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
          scopes: "openid profile",
          confidential: true
        )
      end
    elsif context.was_internal
      add_on.oauth_application&.destroy
    end
  end
end
