require "rails_helper"

RSpec.describe AgentComputerProxy do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }

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
    tunnel = ->(last_used, websockets) { { pid: spawn("sleep 60"), port: 1, kubeconfig: Tempfile.new("kubeconfig"), last_used:, websockets: } }
    forwards.merge!("1:8080" => tunnel.(11.minutes.ago, 0), "2:8080" => tunnel.(11.minutes.ago, 1), "3:8080" => tunnel.(1.minute.ago, 0))
    idle = forwards["1:8080"]

    proxy.send(:sweep_idle_tunnels)

    expect(forwards.keys).to eq([ "2:8080", "3:8080" ])
    expect(Process.wait2(idle[:pid]).last.termsig).to eq(Signal.list["TERM"])
    expect(idle[:kubeconfig].path).to be_nil # unlinked
  ensure
    forwards&.each_value { |t| Process.kill("KILL", t[:pid]) rescue nil }
  end
end
