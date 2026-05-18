# frozen_string_literal: true

module AddOns
  class ResetDemoJob < ApplicationJob
    queue_as :default

    def perform(add_on)
      return unless Flipper.enabled?(:demo_mode, add_on)
      return unless add_on.installed?

      AddOns::InstallJob.perform_later(add_on, add_on.account.owner, force: true)
    end
  end
end
