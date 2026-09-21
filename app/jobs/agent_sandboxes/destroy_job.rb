module AgentSandboxes
  class DestroyJob < ApplicationJob
    queue_as :default

    def perform(agent_sandbox)
      agent_sandbox.destroying!

      cluster = agent_sandbox.cluster
      user = agent_sandbox.user
      connection = K8::Connection.new(cluster, user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      kubectl.(%W[delete sandbox #{agent_sandbox.name} -n default --ignore-not-found])

      agent_sandbox.destroy!
    rescue StandardError => e
      agent_sandbox.failed!
      Rails.logger.error("Failed to destroy agent sandbox #{agent_sandbox.id}: #{e.message}")
      raise
    end
  end
end
