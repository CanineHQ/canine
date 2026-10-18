require "rails_helper"

RSpec.describe AgentComputerProxy do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }

  before { Flipper.enable(:agent_computers, account_user.account) }

  it "checks a signed-in person's access to a computer once, then serves their next requests from the cache" do
    proxy = described_class.new(->(_env) { [ 200, {}, [] ] })
    warden = spy("warden", user: account_user.user)
    env = -> { { "warden" => warden, "rack.session" => { "warden.user.user.key" => [ [ account_user.user.id ], "salt" ] } } }

    3.times { expect(proxy.send(:authenticate_sandbox, computer.id, env.call)).to eq(computer) }
    expect(warden).to have_received(:user).once

    signed_out = { "warden" => double("warden", user: nil), "rack.session" => {} }
    expect(proxy.send(:authenticate_sandbox, computer.id, signed_out)).to be_nil
  end

  it "closes tunnels nobody is using, but never one with a desktop connected" do
    proxy = described_class.new(->(_env) { [ 200, {}, [] ] })
    forwards = proxy.instance_variable_get(:@port_forwards)
    tunnel = ->(last_used, websockets) { { forward: spy("forward"), port: 1, kubeconfig: Tempfile.new("kubeconfig"), last_used:, websockets: } }
    forwards.merge!("1:8080" => tunnel.(11.minutes.ago, 0), "2:8080" => tunnel.(11.minutes.ago, 1), "3:8080" => tunnel.(1.minute.ago, 0))
    idle = forwards["1:8080"]

    proxy.send(:sweep_idle_tunnels)

    expect(forwards.keys).to eq([ "2:8080", "3:8080" ])
    expect(idle[:forward]).to have_received(:stop)
    expect(idle[:kubeconfig].path).to be_nil # unlinked
  end

  it "passes only the WebSocket handshake to the VM, never the person's cookies" do
    proxy = described_class.new(->(_env) { [ 200, {}, [] ] })
    vm = TCPServer.new("127.0.0.1", 0)
    received = Thread.new do
      conn = vm.accept
      request = +""
      request << conn.readpartial(4096) until request.include?("\r\n\r\n")
      conn.write("HTTP/1.1 101 Switching Protocols\r\n\r\n")
      conn.close
      request
    end
    allow(proxy).to receive(:authenticate_sandbox).and_return(computer)
    allow(proxy).to receive(:tunnel).and_return({ port: vm.addr[1], websockets: 0, last_used: Time.current })
    browser, hijacked = UNIXSocket.pair
    env = { "rack.hijack" => -> { hijacked }, "rack.hijack_io" => hijacked, "PATH_INFO" => "/agent_computers/#{computer.id}/proxy/api/ws",
            "HTTP_UPGRADE" => "websocket", "HTTP_CONNECTION" => "Upgrade", "HTTP_SEC_WEBSOCKET_KEY" => "abc==",
            "HTTP_SEC_WEBSOCKET_VERSION" => "13", "HTTP_ORIGIN" => "https://canine.example", "HTTP_COOKIE" => "_canine_session=secret",
            "HTTP_AUTHORIZATION" => "Bearer secret", "QUERY_STRING" => "" }

    proxy.call(env)

    request = received.value
    expect(request).to include("Upgrade: websocket", "Sec-WebSocket-Key: abc==", "Origin: http://127.0.0.1:#{vm.addr[1]}")
    expect(request).not_to include("secret", "Cookie", "Authorization")
    expect(browser.readpartial(100)).to start_with("HTTP/1.1 101")
  ensure
    vm&.close
  end
end
