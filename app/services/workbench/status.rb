module Workbench
  class Status
    STAGES = [
      "Queuing the magic",
      "Building your environment",
      "Spinning up your workspace",
      "Cloning repository"
    ].freeze

    attr_reader :project, :pending_pod

    def initialize(project, pending_pod: nil)
      @project = project
      @pending_pod = pending_pod
    end

    def current_stage
      return 0 unless project.builds.any?
      return 1 unless project.deployments.any?
      return 2 unless pending_pod.present?
      return :git_clone_error if git_clone_failed?
      return 3 unless git_clone_complete?

      :complete
    end

    def error?
      current_stage == :git_clone_error
    end

    def in_progress?
      current_stage.is_a?(Integer)
    end

    def error_message
      return unless error?

      "The git clone step failed. This is usually caused by an expired or unauthorized access token. " \
        "Check that the git credentials have been authorized for SSO access, then redeploy."
    end

    private

    def git_clone_container_status
      return nil unless pending_pod.present?

      init_statuses = pending_pod.status.try(:initContainerStatuses) || []
      init_statuses.find { |c| c.name == "git-clone" }
    end

    def git_clone_failed?
      status = git_clone_container_status
      return false unless status

      terminated = status.state.try(:terminated)
      terminated.present? && terminated.exitCode != 0
    end

    def git_clone_complete?
      status = git_clone_container_status
      return true unless status

      terminated = status.state.try(:terminated)
      terminated.present? && terminated.exitCode == 0
    end
  end
end
