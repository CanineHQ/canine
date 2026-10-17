module AgentComputers
  class DestroyJob < ApplicationJob
    queue_as :agent_computers

    def perform(agent_computer)
      agent_computer.destroying!

      cluster = agent_computer.cluster
      user = agent_computer.user
      connection = K8::Connection.new(cluster, user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      kubectl.(%W[delete namespace #{agent_computer.namespace} --ignore-not-found])

      agent_computer.destroy!
    rescue StandardError => e
      agent_computer.failed!
      Rails.logger.error("Failed to destroy agent computer #{agent_computer.id}: #{e.message}")
      raise
    end
  end
end
