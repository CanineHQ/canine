require "net/http"

module AgentComputers
  # Talks to the computer-use server inside an agent computer's VM (resources/agent_computer/computer_use), through a
  # PortForward. Actions follow Anthropic's computer-use tool: see actions.py in that directory.
  #
  #   computer_use = ComputerUse.new(computer, connection)
  #   computer_use.perform(action: "left_click", coordinate: [640, 400])
  #   computer_use.perform(action: "screenshot")  # => { "image" => "<base64 PNG>", "format" => "png", ... }
  #   computer_use.accessibility(:find, role: "button", name: "save")
  class ComputerUse
    class Error < StandardError; end

    ACCESSIBILITY_OPERATIONS = %w[tree find press set_text].freeze

    def initialize(agent_computer, connection)
      @computer = agent_computer
      @connection = connection
    end

    def perform(action)
      post("/computer-use", action)
    end

    def windows
      get("/windows")
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
      response = PortForward.open(@computer, @connection, AgentComputer::COMPUTER_USE_PORT) do |port|
        Net::HTTP.start("127.0.0.1", port, open_timeout: 10, read_timeout: 120) { |http| http.request(http_request) }
      end
      body = JSON.parse(response.body)
      raise Error, body["error"] || "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body
    rescue PortForward::Error, JSON::ParserError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "Couldn't reach the computer-use server on #{@computer.name}: #{e.message}"
    end
  end
end
