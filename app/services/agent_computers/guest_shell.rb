require "net/ssh"
require "shellwords"

module AgentComputers
  # SSH into an agent computer's VM as the desktop user, through a kubectl port-forward to its launcher pod (KubeVirt's
  # masquerade networking passes the pod's ports into the guest). Uses the key generated for the computer, which the
  # unattended Omarchy install put in authorized_keys.
  #
  #   GuestShell.open(computer, connection) { |shell| shell.run("hostname") }
  class GuestShell
    FORWARD_PORT_RANGE = (19000..19999)

    class Error < StandardError; end
    CommandFailed = Class.new(Error)

    def self.open(agent_computer, connection, &)
      new(agent_computer, connection).open(&)
    end

    def initialize(agent_computer, connection)
      @computer = agent_computer
      @connection = connection
    end

    def open
      K8::Kubeconfig.with_kube_config(@connection.kubeconfig, skip_tls_verify: @connection.cluster.skip_tls_verify) do |kubeconfig|
        with_port_forward(kubeconfig.path) do |port|
          Net::SSH.start("127.0.0.1", AgentComputer::DESKTOP_USER, port:, key_data: [ @computer.ssh_private_key ],
                         keys_only: true, auth_methods: %w[publickey], verify_host_key: :never, non_interactive: true,
                         timeout: 10, keepalive: true, keepalive_interval: 15) do |ssh|
            @ssh = ssh
            yield self
          end
        end
      end
    rescue Net::SSH::Exception, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Timeout::Error, IOError => e
      raise Error, "#{e.class}: #{e.message}"
    end

    # Runs a command (optionally feeding stdin) and returns its combined output; raises unless it exits 0. The
    # environment can hold secrets, so errors name only the command.
    def run(command, stdin: nil, env: {})
      label = command
      command = "#{env.map { |k, v| "#{k}=#{Shellwords.escape(v)}" }.join(" ")} #{command}".strip
      output = +""
      status = nil
      @ssh.open_channel do |channel|
        channel.exec(command) do |_, success|
          raise Error, "couldn't start `#{label}`" unless success

          channel.on_data { |_, data| output << data }
          channel.on_extended_data { |_, _, data| output << data }
          channel.on_request("exit-status") { |_, data| status = data.read_long }
          if stdin
            channel.send_data(stdin)
            channel.eof!
          end
        end
      end
      @ssh.loop
      raise CommandFailed, "`#{label}` exited #{status}:\n#{output.lines.last(40).join}" unless status&.zero?

      output
    end

    private

    def with_port_forward(kubeconfig_path)
      pod = launcher_pod(kubeconfig_path)
      raise Error, "No running VM pod for #{@computer.name}" if pod.blank?

      port = rand(FORWARD_PORT_RANGE)
      pid = spawn({ "KUBECONFIG" => kubeconfig_path },
                  "kubectl", "port-forward", "-n", @computer.namespace, pod, "#{port}:#{AgentComputer::SSH_PORT}",
                  out: File::NULL, err: File::NULL)
      wait_for_port(port)
      yield port
    ensure
      if pid
        Process.kill("TERM", pid) rescue nil
        Process.wait(pid) rescue nil
      end
    end

    def launcher_pod(kubeconfig_path)
      output, = Open3.capture2({ "KUBECONFIG" => kubeconfig_path }, "kubectl", "get", "pods", "-n", @computer.namespace,
                               "-l", "vm.kubevirt.io/name=#{@computer.name}", "--field-selector=status.phase=Running",
                               "-o", "jsonpath={.items[0].metadata.name}")
      output.strip
    end

    def wait_for_port(port)
      20.times do
        TCPSocket.new("127.0.0.1", port).close
        return
      rescue Errno::ECONNREFUSED
        sleep 0.5
      end
      raise Error, "kubectl port-forward to #{@computer.name} didn't start"
    end
  end
end
