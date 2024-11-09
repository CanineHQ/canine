class Projects::Local::Create
  extend LightService::Organizer

  def call
    with(project:, params:, checklist: []).reduce(
      Projects::Local::CheckDockerExists,
      Projects::Local::CheckGithubConnectivity,
      Projects::Save
    )
  end
end
