# frozen_string_literal: true

module Providers
  class Create
    extend LightService::Organizer

    def self.call(provider)
      if provider.provider == Provider::GITHUB_PROVIDER
        with(provider:).reduce(
          Providers::CreateGithubProvider,
        )
      elsif provider.provider == Provider::DOCKER_HUB_PROVIDER
        with(provider:).reduce(
          Providers::CreateDockerImageProvider,
        )
      elsif provider.provider == Provider::GITLAB_PROVIDER
        with(provider:).reduce(
          Providers::CreateGitlabProvider,
        )
      end
    end
  end
end
