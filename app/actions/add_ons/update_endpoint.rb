class AddOns::UpdateEndpoint
  extend LightService::Organizer

  def self.call(add_on, connection, endpoint:, domains:, port:)
    with(add_on:, connection:, endpoint:, domains:, port:).reduce(
      AddOns::ApplyEndpointIngress
    )
  end
end
