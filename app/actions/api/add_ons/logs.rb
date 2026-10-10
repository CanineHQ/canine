# frozen_string_literal: true

# Fetches recent logs and events for every pod in an add-on.
module Api
  module AddOns
    class Logs
      extend LightService::Action
      expects :add_on, :user, :tail_lines
      promises :pods

      executed do |context|
        context.pods = K8::PodLogs.for_add_on(context.add_on, context.user, tail_lines: context.tail_lines)
      rescue StandardError => e
        context.fail_and_return!("Error connecting to cluster: #{e.message}")
      end
    end
  end
end
