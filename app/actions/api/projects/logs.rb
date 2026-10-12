# frozen_string_literal: true

# Fetches recent logs and events for every pod in a project.
module Api
  module Projects
    class Logs
      extend LightService::Action
      expects :project, :user, :tail_lines
      promises :pods

      executed do |context|
        context.pods = K8::PodLogs.for_project(context.project, context.user, tail_lines: context.tail_lines)
      rescue StandardError => e
        context.fail_and_return!("Error connecting to cluster: #{e.message}")
      end
    end
  end
end
