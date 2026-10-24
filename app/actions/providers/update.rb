# frozen_string_literal: true

module Providers
  class Update
    extend LightService::Organizer

    # Swaps in a new access token, validating it the same way as when the provider was created.
    def self.call(provider, access_token:, name: provider.name)
      # Container registries and Bitbucket log in with a username/email that isn't re-entered on update
      provider.username_param = provider.bitbucket? ? provider.email : provider.username
      provider.assign_attributes(access_token:, name:, expires_at: nil, refresh_token: nil)

      with(provider:).reduce(Providers::Create.validator_for(provider))
    end
  end
end
