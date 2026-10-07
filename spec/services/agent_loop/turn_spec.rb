require "rails_helper"

RSpec.describe AgentLoop::Turn do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) do
    computer.agent_tasks.create!(name: "Inbox", instruction: "Check Slack", schedule: "0 * * * *", model: "test/model",
                                 spec: { "blocked_commands" => [ "gh pr merge" ] })
  end
  let(:session) { computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model") }
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

  it "groups calls into activities by intent, runs the shell, blocks commands, and finishes" do
    allow(Tools::ComputerRun).to receive(:call).and_return(MCP::Tool::Response.new([ { type: "text", text: "akula is three repos" } ]))
    allow(client).to receive(:chat).and_return(
      reply("Checking the repo.", [ "computer_run", { intent: "Checking the repo", command: "ls ~/akula" } ]),
      reply(nil, [ "computer_run", { intent: "Checking the repo", command: "cat README.md" } ],
               [ "computer_run", { intent: "Merging the PR", command: "gh pr merge 12" } ]),
      reply(nil, [ "finish", { summary: "akula is three repos." } ])
    )

    expect(described_class.new(session, key).run).to eq(:continue)
    checking = session.activities.sole
    expect(checking).to have_attributes(title: "Checking the repo", description: "Checking the repo.")
    expect(session.messages.last).to have_attributes(role: "tool")

    described_class.new(session, key).run
    merging = session.activities.last
    expect(merging).to have_attributes(title: "Merging the PR")
    expect(merging.actions.sole).to have_attributes(tool: "computer_run", status: "blocked")
    expect(checking.reload.finished_at).to be_present

    expect(described_class.new(session, key).run).to eq(:finished)
    expect(session.reload).to have_attributes(status: "succeeded", summary: "akula is three repos.", turns: 3, input_tokens: 300)
  end

  it "hands a browser task to browse and waits for its job" do
    allow(computer_use).to receive(:browse_start).and_return("id" => "browse-xyz")
    allow(client).to receive(:chat).and_return(reply("On it.", [ "browse", { intent: "Reading Slack", task: "List today's requests in #akula-dev" } ]))

    expect do
      expect(described_class.new(session, key).run).to eq(:waiting_for_tool)
    end.to have_enqueued_job(AgentSessions::BrowseWatchJob)
    action = session.actions.sole
    expect(action).to have_attributes(tool: "browse", status: "running") # finishes when the watch job does
    expect(session.messages.last.content).to include("Started browsing")
  end

  it "pauses when the person is using the computer" do
    allow(Tools::ComputerRun).to receive(:call).and_return(
      MCP::Tool::Response.new([ { type: "text", text: "The person is using this computer. It's free once they've been idle for 20s." } ], error: true)
    )
    allow(client).to receive(:chat).and_return(reply(nil, [ "computer_run", { intent: "Checking", command: "ls" } ],
                                                          [ "computer_run", { intent: "Checking", command: "pwd" } ]))

    expect(described_class.new(session, key).run).to eq(:waiting_for_human)
    expect(session.messages.last(2).map(&:content)).to eq([ "The person is using this computer. It's free once they've been idle for 20s.",
                                                            "Not run: an earlier tool call ended this turn." ])
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
