# frozen_string_literal: true

module Api
  module Providers
    class ShowViewModel
      def initialize(provider)
        @provider = provider
      end

      def as_json
        {
          id: @provider.id,
          type: @provider.provider,
          username: @provider.username,
          git: @provider.git?,
          has_native_registry: @provider.has_native_container_registry?,
          enterprise: @provider.enterprise?
        }
      end
    end
  end
end
