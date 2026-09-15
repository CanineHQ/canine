class AddOns::Update
  extend LightService::Action
  expects :add_on
  promises :add_on

  executed do |context|
    add_on = context.add_on
    was_internal = add_on.internal?
    add_on.save

    # Manage OAuth application for internal auth proxy
    if add_on.internal? && !was_internal
      unless add_on.oauth_application.present?
        add_on.create_oauth_application!(
          name: "Auth Proxy: #{add_on.name}",
          redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
          scopes: "openid profile",
          confidential: true
        )
      end
    elsif was_internal && !add_on.internal?
      add_on.oauth_application&.destroy
      AddOns::CleanupAuthProxyJob.perform_later(add_on) if add_on.installed?
    end
  end
end
