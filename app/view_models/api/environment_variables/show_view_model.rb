# frozen_string_literal: true

module Api
  module EnvironmentVariables
    class ShowViewModel
      def initialize(env_var, reveal: false)
        @env_var = env_var
        @reveal = reveal
      end

      def as_json
        {
          id: @env_var.id,
          name: @env_var.name,
          value: @reveal || @env_var.config? ? @env_var.value : "********",
          storage_type: @env_var.storage_type
        }
      end
    end
  end
end
