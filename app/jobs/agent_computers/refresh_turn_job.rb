module AgentComputers
  # Writes fresh TURN credentials into every running computer before the ones it has expire (AgentComputers::Turn).
  # Runs every few hours (config/initializers/good_job.rb), well inside Turn::TTL, so a missed run or two is harmless.
  class RefreshTurnJob < ApplicationJob
    def perform
      return unless Turn.configured?

      AgentComputer.running.find_each do |agent_computer|
        Turn.refresh(agent_computer)
      rescue Turn::Error, GuestShell::Error => e
        Rails.logger.warn("Couldn't refresh TURN credentials on #{agent_computer.name} (#{agent_computer.id}): #{e.message}")
      end
    end
  end
end
