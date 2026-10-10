module AgentComputers
  # Shuts the VM down (runStrategy Halted). Its disk, and everything installed on it, stays; a stopped computer holds
  # no memory or CPU on the node.
  class StopJob < ApplicationJob
    queue_as :agent_computers

    TIMEOUT = 3.minutes
    POLL_INTERVAL = 3.seconds

    def perform(agent_computer)
      agent_computer.stopping!
      kubectl = K8::Kubectl.new(K8::Connection.new(agent_computer.cluster, agent_computer.user))
      kubectl.(%W[patch vm #{agent_computer.name} -n #{agent_computer.namespace} --type merge -p {"spec":{"runStrategy":"Halted"}}])

      deadline = TIMEOUT.from_now
      until Time.current > deadline
        return agent_computer.stopped! unless running_instance?(kubectl, agent_computer)

        sleep POLL_INTERVAL
      end
      raise "Agent computer VM didn't shut down within #{TIMEOUT.inspect}"
    rescue StandardError => e
      agent_computer.failed!
      Rails.logger.error("Failed to stop agent computer #{agent_computer.id}: #{e.message}")
      raise
    end

    private

    # The VirtualMachineInstance (the running boot) disappears once the guest has shut down
    def running_instance?(kubectl, agent_computer)
      kubectl.(%W[get vmi #{agent_computer.name} -n #{agent_computer.namespace}])
      true
    rescue Cli::CommandFailedError
      false
    end
  end
end
