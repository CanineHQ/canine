class AddOns::Update
  extend LightService::Organizer

  def self.call(add_on)
    with(add_on:).reduce(
      AddOns::Save
    )
  end
end
