# frozen_string_literal: true

require "socket"
require "digest/sha1"
require "shellwords"
require "net/http"

# Rack middleware that reverse-proxies HTTP and WebSocket requests to a sandbox pod
# via kubectl port-forward. Authenticates via Rails session.
#
# Paths:
#   /agent_computers/:id/proxy/*  — Selkies desktop (HTTP + /websockets WebSocket)
#   /agent_computers/:id/api/*    — computer server (HTTP + /ws WebSocket)
class AgentComputerProxy
  # Mirrors AgentComputer::DESKTOP_PORT / COMPUTER_SERVER_PORT; app models aren't autoloadable when middleware loads
  TARGET_PORTS = { "proxy" => 8080, "api" => 8000 }.freeze
  FORWARD_PORT_RANGE = (18000..19000)
  PATH_PATTERN = %r{\A/agent_computers/(\d+)/(proxy|api)(?:/(.*))?}

  AUTH_CACHE_TTL = 60 # seconds

  def initialize(app)
    @app = app
    @port_forwards = {} # "sandbox_id:remote_port" => { pid:, port:, kubeconfig:, last_used: }
    @auth_cache = {}    # "user_id:sandbox_id" => { sandbox:, expires_at: }
    @mutex = Mutex.new
  end

  def call(env)
    request = Rack::Request.new(env)
    match = request.path_info.match(PATH_PATTERN)

    if match
      sandbox_id = match[1].to_i
      remote_port = TARGET_PORTS.fetch(match[2])
      subpath = match[3] || ""

      if websocket?(env)
        handle_websocket(env, request, sandbox_id, remote_port, subpath)
      else
        handle_http(env, request, sandbox_id, remote_port, subpath)
      end
    else
      @app.call(env)
    end
  end

  private

  def log(msg)
    Rails.logger.info("[AgentComputerProxy] #{msg}")
  end

  def log_error(msg)
    Rails.logger.error("[AgentComputerProxy] #{msg}")
  end

  def websocket?(env)
    env["HTTP_UPGRADE"]&.casecmp("websocket")&.zero?
  end

  def authenticate_sandbox(sandbox_id, env)
    user = env["warden"]&.user
    unless user
      log_error "No authenticated user"
      return nil
    end

    cache_key = "#{user.id}:#{sandbox_id}"
    cached = @auth_cache[cache_key]
    if cached && cached[:expires_at] > Time.current
      return cached[:sandbox]
    end

    sandbox = AgentComputer.find_by(id: sandbox_id)
    unless sandbox&.running?
      log_error "Sandbox #{sandbox_id} not found or not running"
      return nil
    end

    account_user = AccountUser.find_by(user: user, account: sandbox.account)
    unless account_user
      log_error "User #{user.id} does not have access to sandbox #{sandbox_id}"
      return nil
    end

    @auth_cache[cache_key] = { sandbox: sandbox, expires_at: Time.current + AUTH_CACHE_TTL }
    sandbox
  end

  def get_local_port(sandbox, remote_port)
    key = "#{sandbox.id}:#{remote_port}"
    @mutex.synchronize do
      entry = @port_forwards[key]
      if entry && port_alive?(entry[:port])
        entry[:last_used] = Time.current
        return entry[:port]
      end

      # Clean up old entry if exists
      cleanup_entry(entry) if entry

      # Start new port-forward
      port = start_port_forward(sandbox, remote_port)
      if port
        @port_forwards[key] = {
          pid: Thread.current[:pf_pid],
          port: port,
          kubeconfig: Thread.current[:pf_kubeconfig],
          last_used: Time.current
        }
      end
      port
    end
  end

  def port_alive?(port)
    s = TCPSocket.new("127.0.0.1", port)
    s.close
    true
  rescue Errno::ECONNREFUSED
    false
  end

  def invalidate_port_forward(sandbox_id, remote_port)
    @mutex.synchronize do
      entry = @port_forwards.delete("#{sandbox_id}:#{remote_port}")
      cleanup_entry(entry) if entry
    end
  end

  def cleanup_entry(entry)
    Process.kill("TERM", entry[:pid]) rescue nil
    entry[:kubeconfig]&.close
    entry[:kubeconfig]&.unlink
  rescue StandardError => e
    log_error "Cleanup error: #{e.message}"
  end

  def start_port_forward(sandbox, remote_port)
    user = sandbox.user
    cluster = sandbox.cluster
    connection = K8::Connection.new(cluster, user)
    kubeconfig_hash = connection.kubeconfig
    kubeconfig_hash = K8::Kubeconfig.apply_tls_settings(kubeconfig_hash, cluster.skip_tls_verify)

    kubeconfig_file = Tempfile.new([ "kubeconfig", ".yaml" ])
    kubeconfig_file.write(kubeconfig_hash.to_yaml)
    kubeconfig_file.flush

    # Find the pod name
    kubectl = K8::Kubectl.new(connection)
    # KubeVirt's launcher pod runs the VM; port-forwarding to it reaches ports inside the guest (masquerade networking)
    pod_name = kubectl.(%W[get pods -n #{sandbox.namespace} -l vm.kubevirt.io/name=#{sandbox.name} --field-selector=status.phase=Running -o jsonpath={.items[0].metadata.name}]).strip
    if pod_name.empty?
      log_error "No pod found for sandbox #{sandbox.name}"
      kubeconfig_file.close
      kubeconfig_file.unlink
      return nil
    end

    local_port = rand(FORWARD_PORT_RANGE)
    cmd = "KUBECONFIG=#{Shellwords.shellescape(kubeconfig_file.path)} kubectl port-forward -n #{Shellwords.shellescape(sandbox.namespace)} #{Shellwords.shellescape(pod_name)} #{local_port}:#{remote_port}"
    log "Spawning: #{cmd}"

    pid = spawn(cmd, out: "/dev/null", err: "/dev/null")
    Process.detach(pid)
    Thread.current[:pf_pid] = pid
    Thread.current[:pf_kubeconfig] = kubeconfig_file

    10.times do |i|
      sleep 0.5
      begin
        s = TCPSocket.new("127.0.0.1", local_port)
        s.close
        log "Port-forward ready on localhost:#{local_port} after #{(i + 1) * 0.5}s"
        return local_port
      rescue Errno::ECONNREFUSED
        next
      end
    end

    log_error "Port-forward timed out"
    Process.kill("TERM", pid) rescue nil
    kubeconfig_file.close
    kubeconfig_file.unlink
    nil
  end

  def handle_http(env, request, sandbox_id, remote_port, subpath)
    sandbox = authenticate_sandbox(sandbox_id, env)
    return [ 401, {}, [ "Unauthorized" ] ] unless sandbox

    local_port = get_local_port(sandbox, remote_port)
    return [ 502, {}, [ "Failed to connect to sandbox" ] ] unless local_port

    # Proxy the HTTP request
    uri = URI("http://127.0.0.1:#{local_port}/#{subpath}")
    uri.query = request.query_string if request.query_string.present?

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 30

    http_method = env["REQUEST_METHOD"]
    path_with_query = uri.request_uri

    case http_method
    when "GET"
      upstream_request = Net::HTTP::Get.new(path_with_query)
    when "POST"
      upstream_request = Net::HTTP::Post.new(path_with_query)
      upstream_request.body = request.body.read
    when "PUT"
      upstream_request = Net::HTTP::Put.new(path_with_query)
      upstream_request.body = request.body.read
    else
      upstream_request = Net::HTTP::Get.new(path_with_query)
    end

    # Forward relevant headers
    upstream_request["Accept"] = env["HTTP_ACCEPT"] if env["HTTP_ACCEPT"]
    upstream_request["Content-Type"] = env["CONTENT_TYPE"] if env["CONTENT_TYPE"]

    response = http.request(upstream_request)

    headers = {}
    response.each_header { |k, v| headers[k] = v unless %w[transfer-encoding connection].include?(k.downcase) }

    [ response.code.to_i, headers, [ response.body || "" ] ]
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE, Net::OpenTimeout => e
    log_error "HTTP proxy error: #{e.class} #{e.message} — clearing stale port-forward"
    invalidate_port_forward(sandbox_id, remote_port)
    [ 502, {}, [ "Proxy error — reconnecting" ] ]
  rescue StandardError => e
    log_error "HTTP proxy error: #{e.class} #{e.message}"
    [ 502, {}, [ "Proxy error" ] ]
  end

  def handle_websocket(env, request, sandbox_id, remote_port, subpath)
    sandbox = authenticate_sandbox(sandbox_id, env)
    return [ 401, {}, [ "Unauthorized" ] ] unless sandbox

    local_port = get_local_port(sandbox, remote_port)
    return [ 502, {}, [ "Failed to connect to sandbox" ] ] unless local_port

    log "WebSocket proxy to localhost:#{local_port}/#{subpath}"

    # Hijack the client connection to get the raw socket
    env["rack.hijack"].call
    client_socket = env["rack.hijack_io"]

    # Connect to upstream and forward the original HTTP upgrade request as-is
    upstream = TCPSocket.new("127.0.0.1", local_port)

    path_for_upstream = "/#{subpath}"
    path_for_upstream += "?#{request.query_string}" if request.query_string.present?

    # Reconstruct the original upgrade request for the upstream
    upgrade_request = "GET #{path_for_upstream} HTTP/1.1\r\n"
    # Forward all relevant headers
    env.each do |key, value|
      next unless key.start_with?("HTTP_") && key != "HTTP_HOST"
      header_name = key.sub("HTTP_", "").split("_").map(&:capitalize).join("-")
      upgrade_request += "#{header_name}: #{value}\r\n"
    end
    upgrade_request += "Host: 127.0.0.1:#{local_port}\r\n"
    upgrade_request += "\r\n"

    upstream.write(upgrade_request)

    # Read the upstream's handshake response and forward it to the client as-is
    upstream_response = +""
    loop do
      readable, = IO.select([ upstream ], nil, nil, 5)
      break unless readable
      upstream_response << upstream.read_nonblock(4096)
      break if upstream_response.include?("\r\n\r\n")
    rescue IO::WaitReadable
      retry
    rescue EOFError
      break
    end

    log "Upstream response: #{upstream_response.lines.first&.strip}"

    # Forward the upstream's response directly to the client
    client_socket.write(upstream_response)

    unless upstream_response.start_with?("HTTP/1.1 101")
      log_error "Upstream WebSocket handshake failed"
      client_socket.close rescue nil
      upstream.close rescue nil
      return [ -1, {}, [] ]
    end

    log "WebSocket passthrough established"

    # Transparent bidirectional proxy — no frame rewriting
    Thread.new do
      proxy_bidirectional(client_socket, upstream)
    ensure
      client_socket.close rescue nil
      upstream.close rescue nil
    end

    [ -1, {}, [] ]
  end

  def proxy_bidirectional(client, upstream)
    loop do
      readable, = IO.select([ client, upstream ], nil, nil, 60)
      break if readable.nil?

      readable.each do |socket|
        data = socket.read_nonblock(16384)
        if socket == client
          upstream.write(data)
        else
          client.write(data)
        end
      rescue EOFError, IOError => e
        log "Proxy ended: #{e.class}"
        return
      end
    end
    log "Proxy timeout (60s idle)"
  end
end
