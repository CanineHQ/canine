# frozen_string_literal: true

module Providers
  class Create
    extend LightService::Organizer

    def self.call(provider)
      with(provider:).reduce(validator_for(provider))
    end

    # Each action checks the token against the provider, fills in `auth`, and saves.
    def self.validator_for(provider)
      if provider.github?
        Providers::CreateGithubProvider
      elsif provider.container_registry?
        Providers::CreateDockerImageProvider
      elsif provider.gitlab?
        Providers::CreateGitlabProvider
      elsif provider.bitbucket?
        Providers::CreateBitbucketProvider
      end
    end
  end
end
