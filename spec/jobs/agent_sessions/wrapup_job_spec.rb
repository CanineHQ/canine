require "rails_helper"

RSpec.describe AgentSessions::WrapupJob do
  it "clears the agent's workspace once a run ends, unless the next run has started on the computer" do
    account_user = create(:account_user)
    computer = AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running)
    session = computer.sessions.create!(trigger: :manual, model: "test/model", status: :succeeded, summary: "Done.")
    computer_use = instance_double(AgentComputers::ComputerUse)
    allow_any_instance_of(AgentComputer).to receive(:computer_use).and_return(computer_use)

    expect(computer_use).to receive(:clear_agent_workspace).once.and_return("closed" => 2, "still_open" => [])
    described_class.perform_now(session)

    computer.sessions.create!(trigger: :manual, model: "test/model", status: :running)
    described_class.perform_now(session) # the next run cleared it as it started, and may have windows open now
  end
end
