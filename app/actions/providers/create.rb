# frozen_string_literal: true

module Providers
  class Create
    extend LightService::Organizer

    def self.call(provider)
      if provider.github?
        with(provider:).reduce(
          Providers::CreateGithubProvider,
        )
      elsif provider.container_registry?
        with(provider:).reduce(
          Providers::CreateDockerImageProvider,
        )
      elsif provider.gitlab?
        with(provider:).reduce(
          Providers::CreateGitlabProvider,
        )
      end
    end
  end
end
