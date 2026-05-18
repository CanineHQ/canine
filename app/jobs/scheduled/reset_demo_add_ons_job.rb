# frozen_string_literal: true

module Scheduled
  class ResetDemoAddOnsJob < ApplicationJob
    queue_as :default

    DEMO_RESET_INTERVAL = ENV.fetch("DEMO_RESET_INTERVAL_HOURS", 24).to_i.hours

    def perform
      AddOn.where(status: :installed).find_each do |add_on|
        next unless Flipper.enabled?(:demo_mode, add_on)
        next unless demo_reset_due?(add_on)

        AddOns::ResetDemoJob.perform_later(add_on)
      end
    end

    private

    def demo_reset_due?(add_on)
      add_on.updated_at + DEMO_RESET_INTERVAL <= Time.current
    end
  end
end
