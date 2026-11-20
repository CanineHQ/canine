require "rails_helper"

RSpec.describe AgentComputers::Stats do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:computer_use) { instance_double(AgentComputers::ComputerUse) }

  def guest(relay)
    allow(computer_use).to receive(:run).and_return("stdout" => "MemTotal: 8000 kB\nMemAvailable: 6000 kB\n---relay\n#{relay}")
    described_class.new(computer, account_user.user).send(:fetch_guest, computer_use)
  end

  it "reads memory and the desktop stream's relay from inside the guest" do
    written = 2.hours.ago.to_i
    used, total, relay = guest("1\n#{written}\n6\n")
    expect([ used, total ]).to eq([ 2000 * 1024, 8000 * 1024 ])
    expect(relay).to have_attributes(relayed?: true, expired?: false, written_at: Time.zone.at(written))

    _, _, relay = guest("0\nnone\n0\n") # no credentials, and Selkies started without them
    expect(relay).to have_attributes(relayed?: false, written_at: nil)
  end
end
