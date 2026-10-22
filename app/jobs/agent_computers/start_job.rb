module AgentComputers
  # Boots a stopped computer (runStrategy Always) and waits for its desktop stream. Omarchy logs straight into the
  # desktop and starts Selkies on its own, so there's nothing to set up again. The boot picks up the computer's memory,
  # in case it was changed while it was stopped or running.
  class StartJob < ApplicationJob
    queue_as :agent_computers

    TIMEOUT = 5.minutes
    POLL_INTERVAL = 3.seconds
    GUEST_ADDRESS = "10.0.2.2" # the guest, as seen from its launcher pod (KubeVirt masquerade networking)

    def perform(agent_computer)
      agent_computer.starting!
      kubectl = K8::Kubectl.new(K8::Connection.new(agent_computer.cluster, agent_computer.user))
      patch = { spec: { runStrategy: "Always", template: { spec: { domain: { memory: { guest: agent_computer.memory } } } } } }
      kubectl.(%W[patch vm #{agent_computer.name} -n #{agent_computer.namespace} --type merge -p #{patch.to_json}])

      deadline = TIMEOUT.from_now
      until Time.current > deadline
        return started(agent_computer) if desktop_streaming?(kubectl, agent_computer)
        if (unschedulable = Unschedulable.reason(JSON.parse(kubectl.(%W[get vm #{agent_computer.name} -n #{agent_computer.namespace} -o json]))))
          raise unschedulable
        end

        sleep POLL_INTERVAL
      end
      raise "Agent computer desktop wasn't back within #{TIMEOUT.inspect}"
    rescue StandardError => e
      agent_computer.fail!(e)
      Rails.logger.error("Failed to start agent computer #{agent_computer.id}: #{e.message}")
      raise
    end

    private

    # Back up: the TURN credentials it had may have expired while it was stopped, and Selkies picks up new ones as
    # they're written
    def started(agent_computer)
      agent_computer.running!
      AgentComputers::Turn.refresh(agent_computer) if AgentComputers::Turn.configured?
    rescue AgentComputers::Turn::Error, AgentComputers::GuestShell::Error => e
      Rails.logger.warn("Couldn't refresh TURN credentials on #{agent_computer.name}: #{e.message}") # RefreshTurnJob tries again
    end

    def desktop_streaming?(kubectl, agent_computer)
      pod = kubectl.(%W[get pods -n #{agent_computer.namespace} -l vm.kubevirt.io/name=#{agent_computer.name}
                        --field-selector=status.phase=Running -o jsonpath={.items[0].metadata.name}]).strip
      return false if pod.empty?

      kubectl.(%W[exec -n #{agent_computer.namespace} #{pod} -c compute --
                  timeout 2 bash -c </dev/tcp/#{GUEST_ADDRESS}/#{AgentComputer::DESKTOP_PORT}])
      true
    rescue Cli::CommandFailedError
      false
    end
  end
end
