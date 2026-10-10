require "rails_helper"

RSpec.describe AgentTasks::ScheduleJob do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let!(:task) { computer.agent_tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model", enabled: true) }
  let(:computer_use) { instance_double(AgentComputers::ComputerUse) }

  before do
    Flipper.enable(:agent_tasks, account_user.account)
    allow(AgentComputers::ComputerUse).to receive(:new).and_return(computer_use)
    task.update_columns(next_run_at: 1.minute.ago)
  end

  it "starts due tasks once the person isn't using the computer, covering what arrived since the last run" do
    allow(computer_use).to receive(:human).and_return("has_screen" => true)
    expect { described_class.perform_now }.not_to change(AgentSession, :count)

    allow(computer_use).to receive(:human).and_return("has_screen" => false)
    expect { described_class.perform_now }.to have_enqueued_job(AgentSessions::TurnJob)
    session = task.sessions.sole
    expect(session).to have_attributes(trigger: "scheduled", status: "queued", model: "test/model")
    expect(session.window_to).to be_within(5.seconds).of(Time.current)
    expect(task.reload.next_run_at).to be > Time.current

    task.update_columns(next_run_at: 1.minute.ago)
    expect { described_class.perform_now }.not_to change(AgentSession, :count) # one session at a time per computer
  end

  it "skips the tasks of accounts without the agent_tasks flag" do
    Flipper.disable(:agent_tasks, account_user.account)
    expect { described_class.perform_now }.not_to change(AgentSession, :count)
    expect(task.reload.next_run_at).to be > Time.current # skipped, not piled up
  end
end
