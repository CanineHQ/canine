class EnvironmentVariables::Update
  extend LightService::Organizer

  def self.call(project:, params:, current_user:)
    with(project:, params:, current_user:).reduce(
      EnvironmentVariables::ParseTextContent,
      EnvironmentVariables::BulkUpdate
    )
  end
end
