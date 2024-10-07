class Services::Create
  extend LightService::Organizer

  def self.call(service, params)
    with(service:, params:).reduce(
      Services::CreateAssociations,
      Services::Save,
    )
  end
end