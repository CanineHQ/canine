class AddOns::UpdateEndpoint
  extend LightService::Organizer

  def self.call(add_on, connection, endpoint:, domains:, port:, internal:)
    was_internal = add_on.internal?
    add_on.update!(internal: internal)

    with(add_on:, was_internal:, connection:, endpoint:, domains:, port:).reduce(
      AddOns::ManageOauthApplication,
      AddOns::ApplyEndpointIngress
    )
  end
end
