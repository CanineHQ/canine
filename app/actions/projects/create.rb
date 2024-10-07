# frozen_string_literal: true

module Projects
  class Create
    extend LightService::Organizer

    def self.call(project, params)
      with(project:, params:).reduce(
        Projects::ValidateGithubRepository,
        Projects::Save,
        Projects::RegisterGithubWebhook,
        Projects::DeployLatestCommit
      )
    end
  end
end
