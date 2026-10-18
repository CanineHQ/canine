require "rails_helper"

RSpec.describe AgentSessions::BrowseWatchJob do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) { computer.tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model") }
  let(:session) { task.sessions.create!(trigger: :manual, model: "test/model", status: :waiting_for_tool) }
  let(:computer_use) { instance_double(AgentComputers::ComputerUse) }

  before { allow(AgentComputers::ComputerUse).to receive(:new).and_return(computer_use) }

  it "doesn't resume a session cancelled during its poll, and stops the browser for one that has ended" do
    activity = session.activities.create!(position: 1, intent: "Reading Slack", title: "Reading Slack", started_at: Time.current)
    browse = activity.actions.create!(tool: "browse", arguments: {}, status: :running, started_at: Time.current)
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

  it "puts each step on the timeline as what it did, with its marked screenshot" do
    activity = session.activities.create!(position: 1, intent: "Paying", title: "Paying", started_at: Time.current)
    activity.actions.create!(tool: "browse", arguments: {}, status: :running, started_at: Time.current)
    png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" # 1×1
    allow(computer_use).to receive(:browse_events).and_return(
      "events" => [ { "n" => 0, "kind" => "step", "goal" => "Pay it", "actions" => [ "click #55" ], "did" => [ "Clicked “Pay invoice”" ],
                      "marked" => "after", "screenshot" => png } ], "running" => true
    )

    described_class.perform_now(session, "browse-1", "Pay the invoice")
    step = session.actions.find_by(tool: "browse_step")
    expect(step).to have_attributes(label: "Clicked “Pay invoice”", screenshot_moment: "after")
    expect(step.result["text"]).to include("Did: Clicked “Pay invoice”")
    expect(step.screenshot).to be_attached
  end

  it "ends the browse when the server has lost its job, instead of polling forever" do
    activity = session.activities.create!(position: 1, intent: "Paying", title: "Paying", started_at: Time.current)
    browse = activity.actions.create!(tool: "browse", arguments: {}, status: :running, started_at: Time.current)
    allow(computer_use).to receive(:browse_events).and_raise(AgentComputers::ComputerUse::Error, "No browse job browse-1")

    expect { described_class.perform_now(session, "browse-1", "Pay the invoice") }.not_to have_enqueued_job(described_class)
    expect(browse.reload).to have_attributes(status: "failed")
    expect(browse.result["text"]).to include("lost")
  end
end
