# frozen_string_literal: true

# Connects a git provider or container registry from an access token.
# params: type (github, gitlab, bitbucket, container_registry), access_token, username, registry_url
module Api
  module Providers
    class Create
      extend LightService::Action
      expects :user, :params
      promises :provider

      executed do |context|
        params = context.params.to_h.with_indifferent_access

        unless Provider::AVAILABLE_PROVIDERS.include?(params[:type])
          context.fail_and_return!("type must be one of: #{Provider::AVAILABLE_PROVIDERS.join(', ')}")
        end

        provider = Provider.new(
          provider: params[:type],
          access_token: params[:access_token],
          username_param: params[:username],
          registry_url: params[:registry_url],
          user: context.user
        )
        context.provider = provider

        result = ::Providers::Create.call(provider)
        context.fail_and_return!(provider.errors.full_messages.to_sentence.presence || result.message) if result.failure?
      end
    end
  end
end
