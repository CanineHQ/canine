module AgentComputers
  # Opens a local port that reaches a port inside an agent computer's VM, for the duration of a block: a kubectl
  # port-forward to the VM's launcher pod (KubeVirt's masquerade networking passes the pod's ports into the guest).
  #
  #   PortForward.open(computer, connection, AgentComputer::SSH_PORT) { |local_port| ... }
  class PortForward
    LOCAL_PORT_RANGE = (19000..19999)

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
      K8::Kubeconfig.with_kube_config(@connection.kubeconfig, skip_tls_verify: @connection.cluster.skip_tls_verify) do |kubeconfig|
        pod = launcher_pod(kubeconfig.path)
        raise Error, "No running VM pod for #{@computer.name}" if pod.blank?

        local_port = rand(LOCAL_PORT_RANGE)
        pid = spawn({ "KUBECONFIG" => kubeconfig.path },
                    "kubectl", "port-forward", "-n", @computer.namespace, pod, "#{local_port}:#{@remote_port}",
                    out: File::NULL, err: File::NULL)
        begin
          wait_for(local_port)
          yield local_port
        ensure
          Process.kill("TERM", pid) rescue nil
          Process.wait(pid) rescue nil
        end
      end
    end

    private

    def launcher_pod(kubeconfig_path)
      output, = Open3.capture2({ "KUBECONFIG" => kubeconfig_path }, "kubectl", "get", "pods", "-n", @computer.namespace,
                               "-l", "vm.kubevirt.io/name=#{@computer.name}", "--field-selector=status.phase=Running",
                               "-o", "jsonpath={.items[0].metadata.name}")
      output.strip
    end

    def wait_for(local_port)
      20.times do
        TCPSocket.new("127.0.0.1", local_port).close
        return
      rescue Errno::ECONNREFUSED
        sleep 0.5
      end
      raise Error, "kubectl port-forward to #{@computer.name} didn't start"
    end
  end
end
