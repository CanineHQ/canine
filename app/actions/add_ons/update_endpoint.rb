class AddOns::UpdateEndpoint
  extend LightService::Organizer

  def self.call(add_on, connection, endpoint:, domains:, port:)
    was_internal = add_on.internal?

    with(add_on:, was_internal:, connection:, endpoint:, domains:, port:).reduce(
      AddOns::ApplyEndpointIngress
    )
  end
end
