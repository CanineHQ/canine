require "rails_helper"

RSpec.describe AgentLoop::Tidy do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) do
    computer.agent_tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model",
                                 spec: {})
  end
  let(:session) { computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model", status: :running) }
  let(:client) { instance_double(Llm::OpenRouter) }

  before do
    account_user.account.agent_provider_keys.create!(api_key: "sk-or-test")
    allow(Llm::OpenRouter).to receive(:new).and_return(client)
  end

  def activity(position, intent)
    session.activities.create!(position:, intent:, title: intent, started_at: Time.current, finished_at: Time.current).tap do |a|
      session.actions.create!(activity: a, tool: "computer_run", arguments: { "command" => "ls" }, status: :done, result: { "text" => "ok" })
    end
  end

  def reply(groups)
    Llm::OpenRouter::Reply.new({ "content" => { groups: }.to_json }, { cost_usd: 0.0001 })
  end

  it "groups a batch of step-sized activities by goal, and continues a goal from the previous batch" do
    find_box, paste, read = activity(1, "Find search box"), activity(2, "Paste query"), activity(3, "Read results")
    allow(client).to receive(:chat).and_return(reply([
      { ids: [ find_box.id, paste.id ], title: "Searching Slack", outcome: "" },
      { ids: [ read.id ], title: "Reading results", outcome: "Found 3 messages" }
    ]))
    described_class.call(session)
    expect(session.activities.reload.map(&:title)).to eq([ "Searching Slack", "Reading results" ])
    expect(find_box.reload.actions.count).to eq(2)
    expect(read.reload).to have_attributes(outcome: "Found 3 messages", tidied_at: be_present)

    more = activity(4, "Scroll results")
    allow(client).to receive(:chat).and_return(reply([ { ids: [ read.id, more.id ], title: "Reading results", outcome: "Found 4 messages" } ]))
    described_class.call(session)
    expect(AgentSessionActivity.exists?(more.id)).to be false
    expect(read.reload).to have_attributes(outcome: "Found 4 messages")
    expect(read.actions.count).to eq(2)

    # A reply that doesn't cover every id in order leaves the activities as they are
    stray = activity(5, "Opening Gmail")
    allow(client).to receive(:chat).and_return(reply([ { ids: [ 999 ], title: "Nonsense" } ]))
    described_class.call(session)
    expect(stray.reload).to have_attributes(title: "Opening Gmail", tidied_at: be_present)
  end
end
