module AgentComputers
  # Creates an agent computer: a KubeVirt VM that installs Omarchy unattended from its ISO (AgentComputer::Omarchy),
  # then, once the installed system is up, logs in over SSH and runs omarchy-setup.sh to stream it with Selkies.
  class ProvisionJob < ApplicationJob
    queue_as :default

    BOOT_TIMEOUT = 15.minutes    # importing the ISO and starting the VM
    INSTALL_TIMEOUT = 40.minutes # the unattended install, from the VM starting to the installed system answering SSH
    DESKTOP_TIMEOUT = 5.minutes  # after setup, until Selkies is streaming
    POLL_INTERVAL = 15.seconds
    FAILURE_GRACE = 3.minutes

    def perform(agent_computer)
      agent_computer.provisioning!

      cluster = agent_computer.cluster
      connection = K8::Connection.new(cluster, agent_computer.user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))
      omarchy = AgentComputer::Omarchy.new(agent_computer)

      kubectl.apply_yaml(K8::Namespace.new(agent_computer).to_yaml)
      kubectl.apply_yaml(build_network_policy_yaml(agent_computer))
      kubectl.apply_yaml(omarchy.cidata_config_map_yaml)
      kubectl.apply_yaml(omarchy.virtual_machine_yaml(labels(agent_computer)))

      wait_until_running(agent_computer, K8::Kubectl.new(connection))
      cluster.info("Installing Omarchy on #{agent_computer.name} (usually 5-10 minutes)...", color: :yellow)
      wait_until_installed(agent_computer, connection)
      cluster.info("Setting up the desktop stream on #{agent_computer.name}...", color: :yellow)
      GuestShell.open(agent_computer, connection) do |shell|
        shell.run("bash -s", stdin: AgentComputer::Omarchy::SETUP_SCRIPT.read, env: omarchy.setup_environment)
      end
      wait_until_streaming(agent_computer, connection)

      agent_computer.running!
      cluster.success("Agent computer #{agent_computer.name} is ready")
    rescue StandardError => e
      agent_computer.failed!
      Rails.logger.error("Failed to provision agent computer #{agent_computer.id}: #{e.message}")
      raise
    end

    private

    # Covers importing the ISO and booting; KubeVirt reports problems like a failed import as a Failure condition
    def wait_until_running(agent_computer, kubectl)
      started = Time.current
      until Time.current > started + BOOT_TIMEOUT
        vm = JSON.parse(kubectl.(%W[get vm #{agent_computer.name} -n #{agent_computer.namespace} -o json]))
        return if vm.dig("status", "printableStatus") == "Running"

        # A failure can be stale from an earlier attempt, so give KubeVirt's backoff time to retry before trusting it
        failure = vm.dig("status", "conditions")&.find { |c| c["type"] == "Failure" && c["status"] == "True" }
        raise "Agent computer VM failed to start: #{failure["message"]}" if failure && Time.current > started + FAILURE_GRACE

        sleep POLL_INTERVAL
      end
      raise "Agent computer VM wasn't running after #{BOOT_TIMEOUT.inspect}"
    end

    # The live ISO also runs sshd, so SSH answering isn't enough: the install is done when our key logs in as the
    # desktop user on a machine with the computer's hostname
    def wait_until_installed(agent_computer, connection)
      deadline = INSTALL_TIMEOUT.from_now
      last_error = nil
      until Time.current > deadline
        begin
          hostname = GuestShell.open(agent_computer, connection) { |shell| shell.run("hostname").strip }
          return if hostname == agent_computer.name

          last_error = "hostname is #{hostname.inspect}"
        rescue GuestShell::Error => e
          last_error = e.message
        end
        sleep POLL_INTERVAL
      end
      raise "Omarchy install didn't finish within #{INSTALL_TIMEOUT.inspect} (last SSH attempt: #{last_error})"
    end

    def wait_until_streaming(agent_computer, connection)
      deadline = DESKTOP_TIMEOUT.from_now
      until Time.current > deadline
        listening = GuestShell.open(agent_computer, connection) { |shell| shell.run("ss -Hltn 'sport = :#{AgentComputer::DESKTOP_PORT}'") }
        return if listening.present?

        sleep 5
      end
      raise "Selkies wasn't listening on port #{AgentComputer::DESKTOP_PORT} within #{DESKTOP_TIMEOUT.inspect} of setup"
    end

    def labels(agent_computer)
      {
        "agent-computer" => agent_computer.name,
        "app.kubernetes.io/managed-by" => "canine"
      }
    end

    # Selkies is unauthenticated, so block every in-cluster connection. Canine reaches the VM (Selkies, and SSH for
    # setup) through kubectl port-forward, which isn't subject to NetworkPolicy.
    def build_network_policy_yaml(agent_computer)
      {
        "apiVersion" => "networking.k8s.io/v1",
        "kind" => "NetworkPolicy",
        "metadata" => { "name" => "deny-all-ingress", "namespace" => agent_computer.namespace },
        "spec" => { "podSelector" => {}, "policyTypes" => [ "Ingress" ] }
      }.to_yaml
    end
  end
end
