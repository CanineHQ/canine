module AgentComputers
  # Boots a stopped computer (runStrategy Always) and waits for its desktop stream. Omarchy logs straight into the
  # desktop and starts Selkies on its own, so there's nothing to set up again.
  class StartJob < ApplicationJob
    queue_as :agent_computers

    TIMEOUT = 5.minutes
    POLL_INTERVAL = 3.seconds
    GUEST_ADDRESS = "10.0.2.2" # the guest, as seen from its launcher pod (KubeVirt masquerade networking)

    def perform(agent_computer)
      agent_computer.starting!
      kubectl = K8::Kubectl.new(K8::Connection.new(agent_computer.cluster, agent_computer.user))
      kubectl.(%W[patch vm #{agent_computer.name} -n #{agent_computer.namespace} --type merge -p {"spec":{"runStrategy":"Always"}}])

      deadline = TIMEOUT.from_now
      until Time.current > deadline
        return agent_computer.running! if desktop_streaming?(kubectl, agent_computer)

        sleep POLL_INTERVAL
      end
      raise "Agent computer desktop wasn't back within #{TIMEOUT.inspect}"
    rescue StandardError => e
      agent_computer.failed!
      Rails.logger.error("Failed to start agent computer #{agent_computer.id}: #{e.message}")
      raise
    end

    private

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
