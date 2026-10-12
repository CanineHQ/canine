require "rails_helper"

RSpec.describe AgentSessions::BrowseWatchJob do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) { computer.tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model") }
  let(:session) { computer.sessions.create!(task: task, trigger: :manual, model: "test/model", status: :waiting_for_tool) }
  let(:computer_use) { instance_double(AgentComputers::ComputerUse) }

  before { allow(AgentComputers::ComputerUse).to receive(:new).and_return(computer_use) }

  it "doesn't resume a session cancelled during its poll, and stops the browser for one that has ended" do
    activity = session.activities.create!(position: 1, intent: "Reading Slack", title: "Reading Slack", started_at: Time.current)
    browse = session.actions.create!(activity:, tool: "browse", arguments: {}, status: :running, started_at: Time.current)
    # The person cancels while the job is long-polling, then the browser reports it finished
    allow(computer_use).to receive(:browse_events) do
      AgentComputer::Session.where(id: session.id).update_all(status: AgentComputer::Session.statuses[:cancelled])
      { "events" => [ { "n" => 0, "kind" => "done", "finished" => true, "result" => "Nothing new." } ], "running" => false }
    end

    expect { described_class.perform_now(session, "browse-1", "Read Slack") }.not_to have_enqueued_job(AgentSessions::TurnJob)
    expect(session.reload).to have_attributes(status: "cancelled")

    browse.reload.update!(status: :running) # as if the browser were still working when the session ended
    expect(computer_use).to receive(:browse_stop).with("browse-1")
    described_class.perform_now(session.reload, "browse-1", "Read Slack") # a queued job loads the session afresh
    expect(browse.reload).to have_attributes(status: "failed")
  end
end
