module AgentComputers
  # Live stats for an agent computer's VM: KubeVirt's view of the VM, metrics-server CPU of its launcher pod (QEMU
  # included), memory and who has the screen from inside the guest (the computer-use server), disk usage from the
  # guest agent, port probes for the services inside the guest, and how Selkies is streaming the desktop.
  class Stats
    include StorageHelper

    Service = Struct.new(:name, :state, :detail, keyword_init: true)

    # How Selkies streams the desktop, as it reports it: its transport ("webrtc" or "websockets") and the TURN relays
    # it hands the browser (hosts only; the credentials that come with them are dropped)
    Stream = Struct.new(:mode, :relays, keyword_init: true) do
      def webrtc? = mode == "webrtc"
      def cloudflare_turn? = relays.any? { |host| host == "turn.cloudflare.com" }
    end

    # Probed from the launcher pod, where the guest is reachable at KubeVirt's masquerade address
    GUEST_ADDRESS = "10.0.2.2"
    SERVICES = {
      "desktop" => AgentComputer::DESKTOP_PORT,
      "ssh" => AgentComputer::SSH_PORT,
      "computer-use" => AgentComputer::COMPUTER_USE_PORT
    }.freeze
    STREAM_SEPARATOR = "--canine-selkies--" # between the HTTP responses in fetch_stream's output

    attr_reader :vmi, :pod, :cpu_used, :memory_used, :memory_total, :disk_used, :disk_size, :services, :stream

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

      # Asked alongside the cluster calls, since each takes a few seconds (the computer-use one opens a port-forward).
      # The client is built here so the thread has nothing to autoload, and joining permits loads so it can't deadlock.
      computer_use = @agent_computer.computer_use
      guest = Thread.new { Rails.application.executor.wrap { fetch_guest(computer_use) } }
      fetch_cpu(namespace)
      fetch_disk(namespace)
      probe_services(namespace)
      fetch_stream(namespace)
      @memory_used, @memory_total = ActiveSupport::Dependencies.interlock.permit_concurrent_loads { guest.value }
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
    def memory_limit = memory_total || memory_to_integer(AgentComputer::MEMORY)

    private

    # From inside the guest: memory in use as Linux counts it, total minus available, so page cache it would drop on
    # demand doesn't count. (The pod's working set counts all the guest RAM QEMU has ever touched, so it sits near the
    # VM's size even when the guest has plenty free: no sign of pressure.) Nils if the server didn't answer.
    def fetch_guest(computer_use)
      meminfo = computer_use.run("cat /proc/meminfo")["stdout"].to_s
      bytes = ->(key) { meminfo[/^#{key}:\s+(\d+) kB/, 1]&.to_i&.*(1024) }
      total, available = bytes.("MemTotal"), bytes.("MemAvailable")
      [ total && available && total - available, total ]
    rescue StandardError => e
      Rails.logger.info("Couldn't read computer #{@agent_computer.id}'s guest stats: #{e.message}")
      [ nil, nil ]
    end

    def condition?(type)
      @vmi&.dig("status", "conditions")&.any? { |c| c["type"] == type && c["status"] == "True" }
    end

    def get_json(command)
      JSON.parse(@kubectl.(command + %w[-o json]))
    rescue Cli::CommandFailedError, JSON::ParserError
      nil
    end

    def fetch_cpu(namespace)
      usage = K8::Metrics::Api::Pod.fetch(@connection, namespace).find { |p| p.name == @pod.metadata.name }
      @cpu_used = usage&.cpu
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

    # Asks Selkies itself, from the launcher pod: /api/status for its transport, /api/turn for the ICE servers it gives
    # the browser (404 without TURN credentials, 409 when it's streaming over WebSockets)
    def fetch_stream(namespace)
      requests = %w[/api/status /api/turn].map do |path|
        %(echo "#{STREAM_SEPARATOR}"; exec 3<>/dev/tcp/#{GUEST_ADDRESS}/#{AgentComputer::DESKTOP_PORT} && ) +
          %(printf 'GET #{path} HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n' >&3 && timeout 2 cat <&3)
      end
      output = @kubectl.(%W[exec -n #{namespace} #{@pod.metadata.name} -c compute -- bash -c #{requests.map { |r| "(#{r})" }.join("; ")}])
      @stream = self.class.parse_stream(output)
    rescue StandardError => e
      # Only the class: the output holds TURN credentials, and parse errors quote it
      Rails.logger.warn("Agent computer #{@agent_computer.id} stream check failed: #{e.class}")
    end

    # The two HTTP responses fetch_stream prints; nil if Selkies didn't answer
    def self.parse_stream(output)
      status, turn = output.split("#{STREAM_SEPARATOR}\n").drop(1).map { |response| response.split("\r\n\r\n", 2) }
      return unless status&.first&.match?(%r{\AHTTP/\S+ 200})

      ice_servers = turn&.first&.match?(%r{\AHTTP/\S+ 200}) ? JSON.parse(turn.last).fetch("iceServers", []) : []
      relays = ice_servers.flat_map { |server| Array(server["urls"]) }.grep(/\Aturns?:/).map { |url| url[/\Aturns?:([^:?]+)/, 1] }
      Stream.new(mode: JSON.parse(status.last)["current_mode"], relays: relays.uniq)
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
