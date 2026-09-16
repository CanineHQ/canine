class AddOns::Update
  extend LightService::Organizer

  def self.call(add_on, connection, was_internal: false)
    with(add_on:, was_internal:, connection:).reduce(
      AddOns::Save,
      AddOns::ManageOAuthApplication,
      AddOns::DeployAuthProxy
    )
  end
end
