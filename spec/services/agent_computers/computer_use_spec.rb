require "rails_helper"

RSpec.describe AgentComputers::ComputerUse do
  it "authenticates to the computer-use server with the computer's token" do
    account_user = create(:account_user)
    computer = AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running)
    allow(AgentComputers::PortForward).to receive(:open).and_yield(18123)
    stub_request(:post, "http://127.0.0.1:18123/run")
      .with(headers: { "Authorization" => "Bearer #{computer.computer_use_token}" })
      .to_return(body: { exit_code: 0, stdout: "hi\n", stderr: "" }.to_json)

    expect(computer.computer_use.run("echo hi")["stdout"]).to eq("hi\n")
  end
end
