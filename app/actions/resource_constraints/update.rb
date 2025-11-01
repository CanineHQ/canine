class ResourceConstraints::Update
  extend LightService::Organizer

  def self.call(resource_constraint, params)
    with(resource_constraint:, params:).reduce(
      ResourceConstraints::Save
    )
  end
end
