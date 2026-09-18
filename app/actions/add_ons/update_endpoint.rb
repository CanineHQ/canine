class AddOns::UpdateEndpoint
  extend LightService::Organizer

  def self.call(add_on, connection, endpoint:, domains:, port:, internal:)
    was_internal = add_on.internal?

    if internal && !add_on.oauth_application.present?
      add_on.create_oauth_application!(
        name: "Auth Proxy: #{add_on.name}",
        redirect_uri: "#{ENV.fetch('APP_HOST')}/oauth2/callback",
        scopes: "openid profile email",
        confidential: true
      )
    elsif !internal && add_on.oauth_application.present?
      add_on.oauth_application.destroy
      add_on.reload
    end

    with(add_on:, was_internal:, connection:, endpoint:, domains:, port:).reduce(
      AddOns::ApplyEndpointIngress
    )
  end
end
