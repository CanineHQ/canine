class Scheduled::CleanupShellSessionsJob < ApplicationJob
  queue_as :default

  def perform
    ShellToken.cleanup_stale_sessions!
    ShellToken.cleanup_expired!
  end
end
