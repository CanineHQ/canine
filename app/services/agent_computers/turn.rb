module AgentComputers
  # Short-lived Cloudflare TURN credentials for a computer's WebRTC desktop stream. KubeVirt's masquerade networking
  # rules out a direct path between the browser and the VM, so the media is relayed through Cloudflare's TURN service.
  #
  # Canine's TURN API token stays here: Canine generates the credentials and writes only them into the VM, at
  # RTC_CONFIG_PATH, which Selkies reads at startup (--rtc-config-json) and watches for changes. (The agent has root in
  # the VM, so anything sent there is the account's to read: the token there would let any tenant mint TURN
  # credentials billed to Canine.) RefreshTurnJob writes fresh ones before these expire.
  #
  #   AgentComputers::Turn.write(shell)      # during setup, before Selkies first starts
  #   AgentComputers::Turn.refresh(computer) # later, over its own SSH session
  module Turn
    TTL = 24.hours
    RTC_CONFIG_PATH = "~/.config/canine/rtc.json"
    TIMEOUT = 15 # seconds

    class Error < StandardError; end

    def self.configured?
      ENV["CLOUDFLARE_TURN_TOKEN_ID"].present? && ENV["CLOUDFLARE_TURN_API_TOKEN"].present?
    end

    # {"iceServers" => [...]}: Cloudflare's STUN and TURN servers, with credentials good for TTL
    def self.rtc_config
      uri = URI("https://rtc.live.cloudflare.com/v1/turn/keys/#{ENV.fetch("CLOUDFLARE_TURN_TOKEN_ID")}/credentials/generate-ice-servers")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.post(uri.path, { ttl: TTL.to_i }.to_json, "Authorization" => "Bearer #{ENV.fetch("CLOUDFLARE_TURN_API_TOKEN")}",
                                                       "Content-Type" => "application/json")
      end
      raise Error, "Cloudflare TURN answered HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      servers = JSON.parse(response.body).fetch("iceServers")
      # Cloudflare's port-53 URLs often time out in browsers (its docs suggest leaving them out)
      { "iceServers" => servers.map { |server| server.merge("urls" => Array(server["urls"]).reject { |url| url.match?(/:53(\?|\z)/) }) } }
    rescue JSON::ParserError, KeyError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "Couldn't get TURN credentials from Cloudflare: #{e.class}: #{e.message}"
    end

    # Writes fresh credentials over an open GuestShell. Replaced in one rename, so Selkies never reads half a file; the
    # file is the desktop user's own and private, which Selkies requires before it trusts it.
    def self.write(shell)
      dir = File.dirname(RTC_CONFIG_PATH)
      shell.run("umask 077 && mkdir -p #{dir} && cat > #{RTC_CONFIG_PATH}.new && mv -f #{RTC_CONFIG_PATH}.new #{RTC_CONFIG_PATH}",
                stdin: rtc_config.to_json)
    end

    def self.refresh(agent_computer)
      GuestShell.open(agent_computer, K8::Connection.new(agent_computer.cluster, agent_computer.user)) { |shell| write(shell) }
    end
  end
end
