require "rails_helper"

RSpec.describe AgentSessions::WrapupJob do
  it "clears the run's workspace once it ends, unless another run there has started" do
    account_user = create(:account_user)
    computer = AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running)
    session = computer.tasks.create!(name: "Task", instruction: "Do it", model: "test/model").sessions.create!(trigger: :manual, model: "test/model", status: :succeeded, summary: "Done.", workspace: 3)
    computer_use = instance_double(AgentComputers::ComputerUse)
    allow_any_instance_of(AgentComputer).to receive(:computer_use).and_return(computer_use)

    expect(computer_use).to receive(:clear_workspace).with(3).once.and_return("closed" => 2, "still_open" => [])
    described_class.perform_now(session)

    computer.tasks.create!(name: "Task", instruction: "Do it", model: "test/model").sessions.create!(trigger: :manual, model: "test/model", status: :running, workspace: 3)
    described_class.perform_now(session) # that run cleared it as it started, and may have windows open there now
  end
end
