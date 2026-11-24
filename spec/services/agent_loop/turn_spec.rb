require "rails_helper"

RSpec.describe AgentLoop::Turn do
  include ActiveSupport::Testing::TimeHelpers
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) do
    computer.tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model")
  end
  let(:session) { task.sessions.create!(trigger: :manual, model: "test/model") }
  let(:key) { account_user.account.agent_provider_keys.create!(api_key: "sk-or-test") }
  let(:client) { instance_double(Llm::OpenRouter) }
  let(:computer_use) { instance_double(AgentComputers::ComputerUse) }

  def reply(content, *calls)
    tool_calls = calls.map.with_index { |(name, args), i| { "id" => "call_#{i}", "type" => "function", "function" => { "name" => name, "arguments" => args.to_json } } }
    Llm::OpenRouter::Reply.new({ "role" => "assistant", "content" => content, "tool_calls" => tool_calls.presence }.compact,
                               { input_tokens: 100, output_tokens: 10, cost_usd: 0.001 })
  end

  before do
    allow(Llm::OpenRouter).to receive(:new).and_return(client)
    allow(AgentComputers::ComputerUse).to receive(:new).and_return(computer_use)
    allow(computer_use).to receive(:connected).and_yield
    allow(computer_use).to receive(:computer).and_return(computer)
  end

  it "groups calls into activities by intent, runs the shell, and finishes" do
    allow(Tools::ComputerRun).to receive(:call).and_return(MCP::Tool::Response.new([ { type: "text", text: "my-app is three repos" } ]))
    allow(client).to receive(:chat).and_return(
      reply("Checking the repo.", [ "computer_run", { intent: "Checking the repo", command: "ls ~/my-app" } ]),
      reply(nil, [ "computer_run", { intent: "Checking the repo", command: "cat README.md" } ],
               [ "computer_run", { intent: "Reading the docs", command: "ls docs" } ]),
      reply(nil, [ "finish", { summary: "my-app is three repos." } ])
    )

    expect(described_class.new(session, key).run).to eq(:continue)
    checking = session.activities.sole
    expect(checking).to have_attributes(title: "Checking the repo", description: "Checking the repo.")
    expect(session.messages.last).to have_attributes(role: "tool")

    described_class.new(session, key).run
    reading = session.activities.last
    expect(reading).to have_attributes(title: "Reading the docs")
    expect(reading.actions.sole).to have_attributes(tool: "computer_run", status: "done")
    expect(checking.reload.finished_at).to be_present

    expect(described_class.new(session, key).run).to eq(:finished)
    expect(session.reload).to have_attributes(status: "succeeded", summary: "my-app is three repos.", turns: 3, input_tokens: 300)
  end

  it "pushes back once on stopping short with budget left, then records the outcome and what it tried" do
    allow(client).to receive(:chat).and_return(
      reply(nil, [ "finish", { summary: "Couldn't add the key.", outcome: "blocked" } ]),
      reply(nil, [ "finish", { summary: "Couldn't add the key.", outcome: "blocked", tried: "browse; the gh CLI" } ])
    )

    expect(described_class.new(session, key).run).to eq(:continue)
    expect(session.messages.last.content).to start_with(AgentLoop::Tools::FINISH_PUSHBACK)
    expect(described_class.new(session, key).run).to eq(:finished)
    expect(session.reload).to have_attributes(status: "succeeded", outcome: "blocked", summary: "Couldn't add the key.\n\nTried: browse; the gh CLI")
    expect(ApplicationController.render(partial: "agent_computers/sessions/status_badge", locals: { session: })).to include("blocked")
  end

  it "remembers notes on the computer for later runs, and forgets them" do
    allow(client).to receive(:chat).and_return(
      reply(nil, [ "remember", { intent: "Noting GitHub", note: "GitHub asks for an emailed code before changing SSH keys" } ],
               [ "remember", { intent: "Noting GitHub", note: "Slack's #dev is muted" } ]),
      reply(nil, [ "forget", { intent: "Noting GitHub", text: "slack's #DEV" } ])
    )

    described_class.new(session, key).run
    expect(computer.reload.long_term_memory).to eq("- GitHub asks for an emailed code before changing SSH keys\n- Slack's #dev is muted")
    expect(session.actions.first.label).to eq("Remembered: GitHub asks for an emailed code before changing SSH keys")
    expect(AgentLoop::SystemPrompt.build(task.sessions.create!(trigger: :manual, model: "test/model"))).to include("- Slack's #dev is muted")

    described_class.new(session, key).run
    expect(computer.reload.long_term_memory).to eq("- GitHub asks for an emailed code before changing SSH keys")
    expect(session.messages.last.content).to eq("Forgot 1 note.")
  end

  it "pauses on a question for the person, without the wait counting against its time limit, until they answer" do
    allow(client).to receive(:chat).and_return(reply(nil, [ "ask_person", { intent: "Signing in to GitHub", question: "The code GitHub texted you", kind: "code" } ]))
    session.update!(started_at: Time.current)

    expect(described_class.new(session, key).run).to eq(:waiting_for_person)
    session.wait_for_person! # (TurnJob does this with the outcome)
    expect(session.question).to have_attributes(tool: "ask_person", status: "running", label: "Asked you: The code GitHub texted you")

    travel(task.max_minutes.minutes + 5.minutes) do
      expect(AgentLoop::Policy.limit_reached(session)).to be_nil # the hour it waited isn't working time
      expect { expect(session.answer!("123456")).to be(true) }.to have_enqueued_job(AgentSessions::TurnJob)
      expect(session.reload).to have_attributes(status: "running", waiting_since: nil, waited_seconds: be >= task.max_minutes.minutes)
      expect(session.messages.last.content).to eq("The person answered your question: 123456")
      expect(session.actions.sole).to have_attributes(status: "done", result: { "text" => "Answered." })
      expect(session.answer!("again")).to be(false) # only while it's waiting
    end
  end

  it "hands a browser task to browse and waits for its job" do
    allow(computer_use).to receive(:browse_start).and_return("id" => "browse-xyz")
    allow(client).to receive(:chat).and_return(reply("On it.", [ "browse", { intent: "Reading Slack", task: "List today's requests in #dev" } ]))

    expect do
      expect(described_class.new(session, key).run).to eq(:waiting_for_tool)
    end.to have_enqueued_job(AgentSessions::BrowseWatchJob)
    action = session.actions.sole
    expect(action).to have_attributes(tool: "browse", status: "running") # finishes when the watch job does
    expect(session.messages.last.content).to include("Started browsing")
  end

  it "doesn't run a call whose arguments were cut off, and tells the model why" do
    cut = Llm::OpenRouter::Reply.new({ "role" => "assistant", "content" => nil, "tool_calls" => [
      { "id" => "call_0", "type" => "function", "function" => { "name" => "computer_run", "arguments" => '{"intent": "x", "command": "ls' } }
    ] }, { input_tokens: 100, output_tokens: 2000, cost_usd: 0.001, finish_reason: "length" })
    allow(client).to receive(:chat).and_return(cut)
    expect(Tools::ComputerRun).not_to receive(:call)

    expect(described_class.new(session, key).run).to eq(:continue)
    expect(session.messages.where(role: "tool").sole.content).to start_with("Not run: your reply was cut off")
  end

  it "skips repeated calls in a reply, and asks again when a reply has no tool calls" do
    allow(Tools::ComputerRun).to receive(:call).and_return(MCP::Tool::Response.new([ { type: "text", text: "ok" } ]))
    allow(client).to receive(:chat).and_return(
      reply(nil, [ "computer_run", { intent: "Checking", command: "ls" } ], [ "computer_run", { intent: "Checking", command: "ls" } ])
    )

    expect(described_class.new(session, key).run).to eq(:continue)
    expect(session.messages.where(role: "tool").last.content).to eq("Not run: the same as an earlier call in this reply.")
  end
end
