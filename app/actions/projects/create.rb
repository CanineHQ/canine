# frozen_string_literal: true

module Projects
  class Create
    extend LightService::Organizer

    def self.call(project, params)
      steps = [
        Projects::ValidateGithubRepository,
        Projects::Save
      ]

      # Only register webhook in non-local mode
      unless Rails.application.config.local_mode
        steps << Projects::RegisterGithubWebhook
      end

      steps << Projects::DeployLatestCommit

      with(project:, params:).reduce(*steps)
    end
  end
end
