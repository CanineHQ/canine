# frozen_string_literal: true

require "openssl"
require "socket"
require "websocket/driver"

# Relays a browser's noVNC WebSocket to KubeVirt's VNC subresource for a VM, which shows the VM's own screen
# (its virtual GPU), so no streaming server is needed inside the guest. Browsers can't authenticate to the
# Kubernetes API, so Canine connects with the cluster's kubeconfig credentials and passes the RFB bytes through.
class KubevirtVncRelay
  UPSTREAM_PROTOCOL = "plain.kubevirt.io"
  READ_SIZE = 64 * 1024

  # websocket-driver wraps an object that can write bytes. It treats anything that responds to #env as the server
  # side of a connection, so the client side must not define it.
  class ClientAdapter
    attr_reader :url

    def initialize(socket, url)
      @socket = socket
      @url = url
    end

    def write(data)
      @socket.write(data)
    end
  end

  class ServerAdapter < ClientAdapter
    attr_reader :env

    def initialize(socket, env)
      super(socket, nil)
      @env = env
    end
  end

  def initialize(namespace:, vm:, kubeconfig:, skip_tls_verify: true, logger: Rails.logger)
    @namespace = namespace
    @vm = vm
    @kubeconfig = kubeconfig
    @skip_tls_verify = skip_tls_verify
    @logger = logger
  end

  # Takes over the Rack connection; returns the hijack response
  def call(env)
    env["rack.hijack"].call
    browser_io = env["rack.hijack_io"]
    upstream_io = connect_upstream

    browser = WebSocket::Driver.rack(ServerAdapter.new(browser_io, env), protocols: %w[binary])
    upstream = WebSocket::Driver.client(ClientAdapter.new(upstream_io, upstream_url), protocols: [ UPSTREAM_PROTOCOL ])
    auth_headers.each { |name, value| upstream.set_header(name, value) }

    browser.on(:message) { |event| upstream.binary(event.data) }
    upstream.on(:message) { |event| browser.binary(event.data) }
    closer = -> { close(browser, upstream, browser_io, upstream_io) }
    browser.on(:close) { closer.call }
    upstream.on(:close) { closer.call }
    upstream.on(:error) { |event| @logger.error("[KubevirtVncRelay] upstream error: #{event.message}") }

    upstream.start
    browser.start
    pump(upstream_io, upstream, closer)
    pump(browser_io, browser, closer)
    [ -1, {}, [] ]
  rescue StandardError => e
    @logger.error("[KubevirtVncRelay] #{e.class}: #{e.message}\n#{e.backtrace&.first(4)&.join("\n")}")
    browser_io&.close rescue nil
    upstream_io&.close rescue nil
    [ -1, {}, [] ]
  end

  private

  def pump(io, driver, closer)
    Thread.new do
      loop { driver.parse(io.readpartial(READ_SIZE)) }
    rescue EOFError, IOError, Errno::ECONNRESET, OpenSSL::SSL::SSLError
      closer.call
    end
  end

  def close(browser, upstream, browser_io, upstream_io)
    return if @closed

    @closed = true
    browser.close rescue nil
    upstream.close rescue nil
    browser_io.close rescue nil
    upstream_io.close rescue nil
  end

  def server
    @server ||= URI(cluster_info.fetch("server"))
  end

  def upstream_url
    "wss://#{server.host}:#{server.port}/apis/subresources.kubevirt.io/v1/namespaces/#{@namespace}/virtualmachineinstances/#{@vm}/vnc"
  end

  def connect_upstream
    tcp = TCPSocket.new(server.host, server.port)
    context = OpenSSL::SSL::SSLContext.new
    # Matches K8::Client, which doesn't verify cluster CAs either
    context.verify_mode = OpenSSL::SSL::VERIFY_NONE if @skip_tls_verify
    if user_info["client-certificate-data"] && user_info["client-key-data"]
      context.cert = OpenSSL::X509::Certificate.new(Base64.decode64(user_info["client-certificate-data"]))
      context.key = OpenSSL::PKey.read(Base64.decode64(user_info["client-key-data"]))
    end
    ssl = OpenSSL::SSL::SSLSocket.new(tcp, context)
    ssl.hostname = server.host
    ssl.sync_close = true
    ssl.connect
    ssl
  end

  def auth_headers
    user_info["token"] ? { "Authorization" => "Bearer #{user_info["token"]}" } : {}
  end

  def context_entry
    current = @kubeconfig["current-context"]
    @kubeconfig["contexts"].find { |c| c["name"] == current }.fetch("context")
  end

  def cluster_info
    @kubeconfig["clusters"].find { |c| c["name"] == context_entry["cluster"] }.fetch("cluster")
  end

  def user_info
    @kubeconfig["users"].find { |u| u["name"] == context_entry["user"] }.fetch("user")
  end
end
