require "net/http"

module AgentComputers
  # Talks to the computer-use server inside an agent computer's VM (resources/agent_computer/computer_use), through a
  # PortForward. Actions follow Anthropic's computer-use tool: see actions.py in that directory.
  #
  #   computer_use = ComputerUse.new(computer, connection)
  #   computer_use.perform(action: "left_click", coordinate: [640, 400])
  #   computer_use.perform(action: "screenshot")  # => { "image" => "<base64 PNG>", "format" => "png", ... }
  #   computer_use.accessibility(:find, role: "button", name: "save")
  #   computer_use.run("uname -a")                     # => { "exit_code" => 0, "stdout" => "Linux ...", "stderr" => "" }
  #   computer_use.terminal(:read, session: "term1")   # => { "screen" => "~ $ ", "running" => "bash", ... }
  #   computer_use.window(:open_app, command: "nautilus")  # => { "window" => { "id" => "0x...", ... } }
  class ComputerUse
    class Error < StandardError; end

    ACCESSIBILITY_OPERATIONS = %w[tree find press set_text wait].freeze
    WINDOW_OPERATIONS = %w[open_app open_url focus close maximize move_to_workspace switch_workspace].freeze
    TERMINAL_OPERATIONS = %w[open send read wait close].freeze

    def initialize(agent_computer, connection)
      @computer = agent_computer
      @connection = connection
    end

    # One tunnel for everything in the block, instead of a new kubectl port-forward (about half a second) per request:
    #   computer_use.connected { computer_use.windows; computer_use.perform(action: "screenshot") }
    def connected
      return yield if @port

      PortForward.open(@computer, @connection, AgentComputer::COMPUTER_USE_PORT) do |port|
        @port = port
        yield
      ensure
        @port = nil
      end
    end

    def computer
      @computer
    end

    def perform(action)
      post("/computer-use", action)
    end

    def windows
      get("/windows")
    end

    # Whether the person has the screen (see human.py in the computer-use server): { "has_screen" => true, ... }
    def human
      get("/human")
    end

    def window(operation, params = {})
      raise ArgumentError, "Unknown window operation #{operation}" unless WINDOW_OPERATIONS.include?(operation.to_s)

      post("/windows/#{operation}", params)
    end

    def run(command, timeout: 30)
      post("/run", { command:, timeout: })
    end

    # browser-use, driving the browser over CDP (see browse.py in the computer-use server). A job runs on its own:
    #   id = browse_start(task: "...", url: "...", model:, api_key:)["id"]
    #   browse_events(id, after: n)  # the steps it has taken, as they happen
    #   browse_stop(id)
    def browse_start(params)
      post("/browse/start", params)
    end

    def browse_events(id, after: -1, wait: 25)
      post("/browse/events", { id:, after:, wait: })
    end

    def browse_stop(id)
      post("/browse/stop", { id: })
    end

    # Terminal programs as text, in tmux sessions: computer_use.terminal(:send, session: "term1", text: "ls", enter: true)
    def terminal(operation, params = {})
      return get("/terminal") if operation.to_s == "list"
      raise ArgumentError, "Unknown terminal operation #{operation}" unless TERMINAL_OPERATIONS.include?(operation.to_s)

      post("/terminal/#{operation}", params)
    end

    def accessibility(operation, params = {})
      raise ArgumentError, "Unknown accessibility operation #{operation}" unless ACCESSIBILITY_OPERATIONS.include?(operation.to_s)

      post("/accessibility/#{operation}", params)
    end

    private

    def get(path)
      request(Net::HTTP::Get.new(path))
    end

    def post(path, body)
      request(Net::HTTP::Post.new(path, "Content-Type" => "application/json").tap { |r| r.body = body.to_json })
    end

    def request(http_request)
      started_at = Time.current
      response = begin
        send_request(@port, http_request) if @port
      rescue SystemCallError, Net::OpenTimeout
        nil # the shared tunnel dropped: use a fresh one for this request
      end
      response ||= PortForward.open(@computer, @connection, AgentComputer::COMPUTER_USE_PORT) { |port| send_request(port, http_request) }
      body = JSON.parse(response.body)
      AgentLoop::Trace.record("computer-use #{http_request.method} #{http_request.path}", started_at:,
                              request: http_request.body && JSON.parse(http_request.body), response: body)
      raise Error, body["error"] || "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body
    rescue PortForward::Error, JSON::ParserError, SystemCallError, IOError, Net::OpenTimeout, Net::ReadTimeout, Net::HTTPBadResponse => e
      # (IOError covers EOFError: the tunnel dropped mid-request) the agent sees it as a failed call and can retry
      error = Error.new("Couldn't reach the computer-use server on #{@computer.name}: #{e.class}: #{e.message}")
      # In the trace too, with how long it hung: a screenshot that hung for the whole read timeout left only a long gap
      AgentLoop::Trace.record("computer-use #{http_request.method} #{http_request.path}", started_at:,
                              request: http_request.body && JSON.parse(http_request.body), error:)
      raise error
    end

    def send_request(port, http_request)
      Net::HTTP.start("127.0.0.1", port, open_timeout: 10, read_timeout: 120) { |http| http.request(http_request) }
    end
  end
end
