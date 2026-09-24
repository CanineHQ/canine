module AgentComputers
  # Live stats for an agent computer's VM: KubeVirt's view of the VM, metrics-server usage of its launcher pod
  # (QEMU included), disk usage from the guest agent, and port probes for the services inside the guest.
  class Stats
    include StorageHelper

    Service = Struct.new(:name, :state, :detail, keyword_init: true)

    # Probed from the launcher pod, where the guest is reachable at KubeVirt's masquerade address
    GUEST_ADDRESS = "10.0.2.2"
    SERVICES = {
      "desktop" => AgentComputer::DESKTOP_PORT,
      "computer-server" => AgentComputer::COMPUTER_SERVER_PORT
    }.freeze

    attr_reader :vmi, :pod, :cpu_used, :memory_used, :disk_used, :disk_size, :services

    def initialize(agent_computer, user)
      @agent_computer = agent_computer
      @connection = K8::Connection.new(agent_computer.cluster, user)
      @kubectl = K8::Kubectl.new(@connection)
      @services = []
    end

    def fetch
      namespace = @agent_computer.namespace
      @vmi = get_json(%W[get vmi #{@agent_computer.name} -n #{namespace}])
      @pod = K8::Client.new(@connection).get_pods(namespace:, label_selector: "vm.kubevirt.io/name=#{@agent_computer.name}")
        .find { |p| p.status.phase == "Running" }
      return self unless phase == "Running" && @pod

      fetch_usage(namespace)
      fetch_disk(namespace)
      probe_services(namespace)
      self
    end

    def phase = @vmi&.dig("status", "phase")
    def ip = @vmi&.dig("status", "interfaces", 0, "ipAddress")
    def node = @vmi&.dig("status", "nodeName")
    def guest_os = @vmi&.dig("status", "guestOSInfo", "prettyName").presence
    def paused? = condition?("Paused")
    def guest_agent_connected? = condition?("AgentConnected")

    def started_at
      running = @vmi&.dig("status", "phaseTransitionTimestamps")&.find { |t| t["phase"] == "Running" }
      running && Time.parse(running["phaseTransitionTimestamp"])
    end

    def cpu_limit = AgentComputer::CPU_CORES * 1000
    def memory_limit = memory_to_integer(AgentComputer::MEMORY)

    private

    def condition?(type)
      @vmi&.dig("status", "conditions")&.any? { |c| c["type"] == type && c["status"] == "True" }
    end

    def get_json(command)
      JSON.parse(@kubectl.(command + %w[-o json]))
    rescue Cli::CommandFailedError, JSON::ParserError
      nil
    end

    def fetch_usage(namespace)
      usage = K8::Metrics::Api::Pod.fetch(@connection, namespace).find { |p| p.name == @pod.metadata.name }
      @cpu_used = usage&.cpu
      @memory_used = usage&.memory
    rescue StandardError => e
      Rails.logger.warn("Agent computer #{@agent_computer.id} metrics unavailable: #{e.message}")
    end

    # Needs qemu-guest-agent in the guest; the root filesystem is the computer's disk
    def fetch_disk(namespace)
      raw = @kubectl.(%W[get --raw /apis/subresources.kubevirt.io/v1/namespaces/#{namespace}/virtualmachineinstances/#{@agent_computer.name}/filesystemlist])
      root = JSON.parse(raw)["items"]&.find { |fs| fs["mountPoint"] == "/" }
      @disk_used = root&.dig("usedBytes")
      @disk_size = root&.dig("totalBytes")
    rescue StandardError => e
      Rails.logger.warn("Agent computer #{@agent_computer.id} disk stats unavailable: #{e.message}")
    end

    def probe_services(namespace)
      checks = SERVICES.map { |name, port| %(timeout 2 bash -c "</dev/tcp/#{GUEST_ADDRESS}/#{port}" 2>/dev/null && echo "#{name} RUNNING" || echo "#{name} STOPPED") }
      output = @kubectl.(%W[exec -n #{namespace} #{@pod.metadata.name} -c compute -- sh -c #{checks.join("; ")}])
      output.each_line(chomp: true) do |line|
        name, state = line.split
        @services << Service.new(name:, state:, detail: "port #{SERVICES[name]}") if SERVICES.key?(name)
      end
    rescue StandardError => e
      Rails.logger.warn("Agent computer #{@agent_computer.id} service probes failed: #{e.message}")
    end
  end
end
