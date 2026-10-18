# frozen_string_literal: true

require "socket"
require "digest/sha1"
require "shellwords"
require "net/http"

# Rack middleware that reverse-proxies HTTP and WebSocket requests to an agent computer's VM
# via kubectl port-forward. Authenticates via Rails session.
#
#   /agent_computers/:id/proxy/*  — Selkies desktop (HTTP + its signaling WebSocket). The computer-use server isn't
#                                   reachable this way: it runs commands on the computer, for Canine alone.
class AgentComputerProxy
  # Mirrors AgentComputer::DESKTOP_PORT; app models aren't autoloadable when middleware loads
  DESKTOP_PORT = 8080
  FORWARD_PORT_RANGE = (18000..19000)
  PATH_PATTERN = %r{\A/agent_computers/(\d+)/proxy(?:/(.*))?}

  AUTH_CACHE_TTL = 60 # seconds
  # A tunnel is a kubectl process plus a kubeconfig tempfile, so one nobody uses is closed: none of its WebSockets open
  # (an open desktop always has Selkies' signaling one) and no request through it for this long. Checked every
  # SWEEP_EVERY. Closing one that's still wanted only costs the next request a new port-forward.
  IDLE_TUNNEL_TTL = 10 * 60 # seconds
  SWEEP_EVERY = 60 # seconds

  def initialize(app)
    @app = app
    @port_forwards = {} # "sandbox_id:remote_port" => { pid:, port:, kubeconfig:, last_used:, websockets: }
    @auth_cache = {}    # "<session key>:sandbox_id" => { sandbox:, expires_at: }
    @mutex = Mutex.new
  end

  def call(env)
    request = Rack::Request.new(env)
    match = request.path_info.match(PATH_PATTERN)

    if match
      sandbox_id = match[1].to_i
      remote_port = DESKTOP_PORT
      subpath = match[2] || ""

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

  # Opening the desktop sends many requests through here (Selkies' page and assets, its WebSocket, the health check),
  # so a check is cached for AUTH_CACHE_TTL. The cache key is Devise's session entry (the user's id and password salt),
  # read from the cookie, so a cached request doesn't load the user at all; signing out removes the entry.
  def authenticate_sandbox(sandbox_id, env)
    signed_in_as = env["rack.session"]&.[]("warden.user.user.key")
    cache_key = "#{signed_in_as.inspect}:#{sandbox_id}" if signed_in_as
    cached = cache_key && @auth_cache[cache_key]
    return cached[:sandbox] if cached && cached[:expires_at] > Time.current

    user = env["warden"]&.user
    unless user
      log_error "No authenticated user"
      return nil
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

    @auth_cache[cache_key] = { sandbox: sandbox, expires_at: Time.current + AUTH_CACHE_TTL } if cache_key
    sandbox
  end

  def get_local_port(sandbox, remote_port)
    tunnel(sandbox, remote_port)&.fetch(:port)
  end

  # The open tunnel to the computer's port, or a new one; nil if one couldn't be opened
  def tunnel(sandbox, remote_port)
    key = "#{sandbox.id}:#{remote_port}"
    @mutex.synchronize do
      @sweeper ||= Thread.new { sweep_loop } # in the process serving requests, so after Puma forks its workers
      entry = @port_forwards[key]
      if entry && port_alive?(entry[:port])
        entry[:last_used] = Time.current
        return entry
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
          last_used: Time.current,
          websockets: 0
        }
      end
    end
  end

  def sweep_loop
    loop do
      sleep SWEEP_EVERY
      sweep_idle_tunnels
    end
  rescue StandardError => e
    log_error "Tunnel sweep stopped: #{e.class} #{e.message}"
    @sweeper = nil # the next request starts another
  end

  def sweep_idle_tunnels
    idle_since = Time.current - IDLE_TUNNEL_TTL
    @mutex.synchronize do
      @port_forwards.delete_if do |key, entry|
        next false if entry[:websockets].positive? || entry[:last_used] > idle_since

        log "Closing idle tunnel #{key}"
        cleanup_entry(entry)
        true
      end
    end
  end

  # Whether kubectl's local listener is up. This runs under @mutex, so it's capped: a wedged listener mustn't block
  # every other proxy request. (A listener being up doesn't prove the tunnel works — a request that fails through it
  # invalidates the entry, so a dead-but-listening port gets rebuilt rather than reused forever.)
  def port_alive?(port)
    Socket.tcp("127.0.0.1", port, connect_timeout: 1) { true }
  rescue SystemCallError, IO::TimeoutError
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
    # kubectl itself, not a shell around it, so killing the pid ends the tunnel
    cmd = %W[kubectl port-forward -n #{sandbox.namespace} #{pod_name} #{local_port}:#{remote_port}]
    log "Spawning: #{cmd.shelljoin}"

    pid = spawn({ "KUBECONFIG" => kubeconfig_file.path }, *cmd, out: "/dev/null", err: "/dev/null")
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
    # A cached port-forward whose local port still listens but whose tunnel is dead (after a sleep, a network blip
    # or a VM restart) fails here, often as a read timeout. Clear it so the next request rebuilds it, instead of
    # reusing the dead tunnel forever.
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE, Net::OpenTimeout, Net::ReadTimeout, IOError, SocketError, EOFError => e
    log_error "HTTP proxy error: #{e.class} #{e.message} — clearing stale port-forward"
    invalidate_port_forward(sandbox_id, remote_port)
    [ 502, {}, [ "Proxy error — reconnecting" ] ]
  rescue StandardError => e
    log_error "HTTP proxy error: #{e.class} #{e.message} — clearing stale port-forward"
    invalidate_port_forward(sandbox_id, remote_port)
    [ 502, {}, [ "Proxy error" ] ]
  end

  def handle_websocket(env, request, sandbox_id, remote_port, subpath)
    sandbox = authenticate_sandbox(sandbox_id, env)
    return [ 401, {}, [ "Unauthorized" ] ] unless sandbox

    forward = tunnel(sandbox, remote_port)
    return [ 502, {}, [ "Failed to connect to sandbox" ] ] unless forward
    local_port = forward[:port]

    log "WebSocket proxy to localhost:#{local_port}/#{subpath}"

    # Hijack the client connection to get the raw socket
    env["rack.hijack"].call
    client_socket = env["rack.hijack_io"]

    # Connect to upstream and forward the original HTTP upgrade request as-is
    begin
      upstream = TCPSocket.new("127.0.0.1", local_port)
    rescue SystemCallError => e
      log_error "WebSocket upstream connect failed: #{e.class} — clearing stale port-forward"
      invalidate_port_forward(sandbox_id, remote_port)
      client_socket.close rescue nil
      return [ -1, {}, [] ]
    end

    path_for_upstream = "/#{subpath}"
    path_for_upstream += "?#{request.query_string}" if request.query_string.present?

    # Reconstruct the original upgrade request for the upstream
    upgrade_request = "GET #{path_for_upstream} HTTP/1.1\r\n"
    # Forward all relevant headers
    env.each do |key, value|
      next unless key.start_with?("HTTP_") && !%w[HTTP_HOST HTTP_ORIGIN].include?(key)
      header_name = key.sub("HTTP_", "").split("_").map(&:capitalize).join("-")
      upgrade_request += "#{header_name}: #{value}\r\n"
    end
    upgrade_request += "Host: 127.0.0.1:#{local_port}\r\n"
    # Servers like Selkies 2.0 reject upgrades whose Origin doesn't match their Host. The user is already
    # authenticated above, so present the request as same-origin to the upstream.
    upgrade_request += "Origin: http://127.0.0.1:#{local_port}\r\n" if env["HTTP_ORIGIN"]
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
      # No 101 (often an empty response: the tunnel listens but is dead). Clear the port-forward so the client's
      # next reconnect rebuilds it, rather than hitting the same dead tunnel and looping forever.
      log_error "Upstream WebSocket handshake failed — clearing stale port-forward"
      invalidate_port_forward(sandbox_id, remote_port)
      client_socket.close rescue nil
      upstream.close rescue nil
      return [ -1, {}, [] ]
    end

    log "WebSocket passthrough established"

    # Transparent bidirectional proxy — no frame rewriting. While it's open the tunnel isn't idle, however quiet it is.
    @mutex.synchronize { forward[:websockets] += 1 }
    Thread.new do
      proxy_bidirectional(client_socket, upstream)
    ensure
      client_socket.close rescue nil
      upstream.close rescue nil
      @mutex.synchronize do
        forward[:websockets] -= 1
        forward[:last_used] = Time.current
      end
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
