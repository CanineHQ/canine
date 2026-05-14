# frozen_string_literal: true

module Scheduled
  class ResetDemoProjectsJob < ApplicationJob
    queue_as :default

    DEMO_RESET_INTERVAL = ENV.fetch("DEMO_RESET_INTERVAL_HOURS", 24).to_i.hours

    def perform
      Project.where(status: :deployed).find_each do |project|
        next unless Flipper.enabled?(:demo_mode, project)
        next unless demo_reset_due?(project)

        Projects::ResetDemoJob.perform_later(project)
      end
    end

    private

    def demo_reset_due?(project)
      last_deployed = project.last_deployment_at
      return true if last_deployed.nil?

      last_deployed + DEMO_RESET_INTERVAL <= Time.current
    end
  end
end
