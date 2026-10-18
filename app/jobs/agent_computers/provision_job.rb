module AgentComputers
  # Creates an agent computer: a KubeVirt VM that installs Omarchy unattended from its ISO (AgentComputers::Omarchy),
  # then, once the installed system is up, logs in over SSH, copies in the computer-use server, and runs
  # omarchy-setup.sh to stream it with Selkies.
  class ProvisionJob < ApplicationJob
    queue_as :agent_computers # provision/start/stop/destroy, which someone is usually waiting on

    BOOT_TIMEOUT = 15.minutes    # importing the ISO and starting the VM
    INSTALL_TIMEOUT = 40.minutes # the unattended install, from the VM starting to the installed system answering SSH
    DESKTOP_TIMEOUT = 5.minutes  # after setup, until Selkies is streaming
    POLL_INTERVAL = 15.seconds
    FAILURE_GRACE = 3.minutes

    def perform(agent_computer)
      agent_computer.update!(status: :provisioning, provision_stage: 0)
      agent_computer.log_outputs.delete_all # a retry starts a fresh log

      connection = K8::Connection.new(agent_computer.cluster, agent_computer.user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(agent_computer))
      omarchy = AgentComputers::Omarchy.new(agent_computer)

      kubectl.apply_yaml(K8::Namespace.new(agent_computer).to_yaml)
      kubectl.apply_yaml(build_network_policy_yaml(agent_computer))
      kubectl.apply_yaml(omarchy.cidata_config_map_yaml)
      kubectl.apply_yaml(omarchy.virtual_machine_yaml(labels(agent_computer)))

      stage(agent_computer, 1, "Downloading the Omarchy ISO (#{AgentComputers::Omarchy::ISO_DISK_SIZE}) and starting the VM...")
      wait_until_running(agent_computer, K8::Kubectl.new(connection))
      stage(agent_computer, 2, "Installing Omarchy (usually 5-10 minutes)...")
      wait_until_installed(agent_computer, connection)
      stage(agent_computer, 3, "Setting up the desktop stream and the computer-use server...")
      GuestShell.open(agent_computer, connection) do |shell|
        shell.run("rm -rf ~/.local/share/canine/computer_use ~/.local/share/canine/bigarrow && mkdir -p ~/.local/share/canine && tar -xzf - -C ~/.local/share/canine",
                  stdin: AgentComputers::Omarchy.computer_use_archive)
        shell.run("bash -s", stdin: AgentComputers::Omarchy::SETUP_SCRIPT.read, env: omarchy.setup_environment) { |line| agent_computer.info(line) }
      end
      stage(agent_computer, 4, "Waiting for the desktop stream...")
      wait_until_streaming(agent_computer, connection)

      agent_computer.running!
      agent_computer.success("#{agent_computer.name} is ready")
    rescue StandardError => e
      agent_computer.error(e.message)
      agent_computer.fail!(e)
      Rails.logger.error("Failed to provision agent computer #{agent_computer.id}: #{e.message}")
      raise
    end

    private

    def stage(agent_computer, index, line)
      agent_computer.update!(provision_stage: index)
      agent_computer.info(line, color: :yellow)
    end

    # Covers importing the ISO and booting; KubeVirt reports problems like a failed import as a Failure condition
    def wait_until_running(agent_computer, kubectl)
      started = Time.current
      reported = nil
      until Time.current > started + BOOT_TIMEOUT
        vm = JSON.parse(kubectl.(%W[get vm #{agent_computer.name} -n #{agent_computer.namespace} -o json]))
        return if vm.dig("status", "printableStatus") == "Running"

        reported = report_download(agent_computer, kubectl, reported)
        if (unschedulable = Unschedulable.reason(vm))
          raise unschedulable
        end

        # A failure can be stale from an earlier attempt, so give KubeVirt's backoff time to retry before trusting it
        failure = vm.dig("status", "conditions")&.find { |c| c["type"] == "Failure" && c["status"] == "True" }
        raise "Agent computer VM failed to start: #{failure["message"]}" if failure && Time.current > started + FAILURE_GRACE

        sleep POLL_INTERVAL
      end
      raise "Agent computer VM wasn't running after #{BOOT_TIMEOUT.inspect}"
    end

    # The ISO's import progress (CDI reports e.g. "42.17%"), logged every 10%; returns the last one logged
    def report_download(agent_computer, kubectl, reported)
      progress = kubectl.(%W[get dv #{agent_computer.name}-iso -n #{agent_computer.namespace} -o jsonpath={.status.progress}]).to_f.floor(-1)
      return reported if progress.zero? || progress == reported

      agent_computer.info("Downloaded #{progress.to_i}% of the ISO")
      progress
    rescue Cli::CommandFailedError
      reported # the DataVolume isn't there yet
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

    # Selkies (the desktop stream) and the computer-use server (shell commands, the logged-in browser) are both
    # unauthenticated and listen on the VM's interface, so block every in-cluster connection: without this, any pod
    # in the cluster could drive the computer. Canine reaches the VM (both, and SSH for setup) through kubectl
    # port-forward, which isn't subject to NetworkPolicy.
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
