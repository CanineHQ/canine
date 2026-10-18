require "rails_helper"

RSpec.describe AgentTasks::ScheduleJob do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let!(:task) { computer.tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model", enabled: true) }
  before do
    Flipper.enable(:agent_computers, account_user.account)
    task.update_columns(next_run_at: 1.minute.ago)
  end

  it "starts due tasks alongside the person and other runs, but not a task that's still running" do
    expect { described_class.perform_now }.to have_enqueued_job(AgentSessions::TurnJob)
    session = task.sessions.sole
    expect(session).to have_attributes(trigger: "scheduled", status: "queued", model: "test/model")
    expect(session.window_to).to be_within(5.seconds).of(Time.current)
    expect(task.reload.next_run_at).to be > Time.current

    other = computer.tasks.create!(name: "Mail", instruction: "Check mail", schedule: "0 * * * *", model: "test/model", enabled: true)
    [ task, other ].each { |t| t.update_columns(next_run_at: 1.minute.ago) }
    expect { described_class.perform_now }.to change(AgentComputer::Session, :count).by(1) # Mail, beside Inbox's run
    expect(task.reload.next_run_at).to be < Time.current # still due: it starts once its last run is done
  end

  it "skips the tasks of accounts without the agent_computers flag" do
    Flipper.disable(:agent_computers, account_user.account)
    expect { described_class.perform_now }.not_to change(AgentComputer::Session, :count)
    expect(task.reload.next_run_at).to be > Time.current # skipped, not piled up
  end
end
