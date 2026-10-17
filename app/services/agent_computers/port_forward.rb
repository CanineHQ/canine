module AgentComputers
  # Opens a local port that reaches a port inside an agent computer's VM, for the duration of a block: a kubectl
  # port-forward to the VM's launcher pod (KubeVirt's masquerade networking passes the pod's ports into the guest).
  #
  #   PortForward.open(computer, connection, AgentComputer::SSH_PORT) { |local_port| ... }
  class PortForward
    LOCAL_PORT_RANGE = (19000..19999)
    START_TIMEOUT = 30 # seconds

    class Error < StandardError; end

    def self.open(agent_computer, connection, remote_port, &)
      new(agent_computer, connection, remote_port).open(&)
    end

    def initialize(agent_computer, connection, remote_port)
      @computer = agent_computer
      @connection = connection
      @remote_port = remote_port
    end

    def open
      started_at = Time.current
      K8::Kubeconfig.with_kube_config(@connection.kubeconfig, skip_tls_verify: @connection.cluster.skip_tls_verify) do |kubeconfig|
        pod = launcher_pod(kubeconfig.path)
        raise Error, "No running VM pod for #{@computer.name}" if pod.blank?

        local_port = rand(LOCAL_PORT_RANGE)
        errors = Tempfile.new("port-forward")
        pid = spawn({ "KUBECONFIG" => kubeconfig.path },
                    "kubectl", "port-forward", "-n", @computer.namespace, pod, "#{local_port}:#{@remote_port}",
                    out: File::NULL, err: errors.path)
        begin
          wait_for(local_port, pid, errors)
          trace(started_at, pod:, local_port:)
          yield local_port
        ensure
          Process.kill("TERM", pid) rescue nil
          Process.wait(pid) rescue nil
          errors.close!
        end
      end
    rescue Error => e
      trace(started_at, error: e)
      raise
    end

    private

    # How long the tunnel took to open (most of a turn's start, on a slow connection), or why it didn't
    def trace(started_at, error: nil, **details)
      AgentLoop::Trace.record("kubectl port-forward :#{@remote_port}", started_at:, request: { computer: @computer.name, remote_port: @remote_port },
                                                                        response: details.presence, error:)
    end

    def launcher_pod(kubeconfig_path)
      output, = Open3.capture2({ "KUBECONFIG" => kubeconfig_path }, "kubectl", "get", "pods", "-n", @computer.namespace,
                               "-l", "vm.kubevirt.io/name=#{@computer.name}", "--field-selector=status.phase=Running",
                               "-o", "jsonpath={.items[0].metadata.name}")
      output.strip
    end

    # kubectl takes ~10 seconds to start forwarding (most of it authenticating to the cluster), so 10 seconds of
    # waiting failed about one start in five. If kubectl exits instead, say why.
    def wait_for(local_port, pid, errors)
      deadline = Time.current + START_TIMEOUT
      while Time.current < deadline
        begin
          return TCPSocket.new("127.0.0.1", local_port).close
        rescue Errno::ECONNREFUSED
          raise Error, "kubectl port-forward to #{@computer.name} failed: #{File.read(errors.path).strip.presence || "it exited"}" if Process.wait(pid, Process::WNOHANG)

          sleep 0.5
        end
      end
      raise Error, "kubectl port-forward to #{@computer.name} didn't start in #{START_TIMEOUT} seconds"
    end
  end
end
