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
      last_build_at = project.builds.maximum(:created_at)
      return true if last_build_at.nil?

      last_build_at + DEMO_RESET_INTERVAL <= Time.current
    end
  end
end
