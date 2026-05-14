# frozen_string_literal: true

module Projects
  class ResetDemoJob < ApplicationJob
    queue_as :default

    def perform(project)
      return unless Flipper.enabled?(:demo_mode, project)
      return unless project.deployed?

      Projects::DeployLatestCommit.execute(
        project: project,
        current_user: project.account.owner
      )
    end
  end
end
