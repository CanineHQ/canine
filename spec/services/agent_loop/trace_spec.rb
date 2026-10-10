require "rails_helper"

RSpec.describe AgentLoop::Trace do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:task) { computer.agent_tasks.create!(name: "Inbox", instruction: "Report the newest email", schedule: "0 * * * *", model: "test/model") }
  let(:session) { computer.agent_sessions.create!(agent_task: task, trigger: :manual, model: "test/model", status: :running) }
  let(:pushed) { [] }
  let(:screenshot) { "A" * 2000 }

  before { allow(AgentLoop::Trace::Exporter).to receive(:push) { |span| pushed << span } }

  it "traces a session as one tree: the session, its turns, tool calls with screenshots, and the calls under them" do
    stub_const("ENV", ENV.to_h.merge("LANGFUSE_HOST" => "http://localhost:3100", "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk"))
    described_class.session(session, "turn 1") do
      described_class.record("openrouter chat", started_at: Time.current, request: {}, response: {}, model: "test/model",
                                                usage: { input_tokens: 100, output_tokens: 5, cost_usd: 0.001 },
                                                input: [ { role: "user", content: "Start now." } ], output: { role: "assistant", content: "On it" })
      described_class.span("computer_action.left_click", type: "tool", input: { action: "left_click" }) do |traced|
        described_class.record("computer-use POST /computer-use", started_at: Time.current, request: { action: "screenshot" },
                                                                   response: { "image" => screenshot })
        traced.output = "Clicked"
        traced.image = screenshot
      end
    end
    session.update!(status: :succeeded, summary: "Newest email: Chris", finished_at: Time.current)
    described_class.finish(session)

    chat, request, tool, turn, root = pushed
    expect(pushed.map(&:trace_id).uniq).to eq([ described_class.trace_id(session) ]) # one trace for the whole session
    expect([ turn.parent_id, chat.parent_id, tool.parent_id, request.parent_id ]).to eq([ root.span_id, turn.span_id, turn.span_id, tool.span_id ])
    expect(chat.attributes).to include("langfuse.observation.type" => "generation", "langfuse.observation.input" => [ { role: "user", content: "Start now." } ].to_json)
    expect(JSON.parse(tool.attributes["langfuse.observation.output"])).to eq(
      [ { "type" => "text", "text" => "Clicked" }, { "type" => "image_url", "image_url" => { "url" => "data:image/png;base64,#{screenshot}" } } ]
    )
    expect(request.attributes["langfuse.observation.output"]).not_to include(screenshot) # shown once, on the tool call
    expect(root.attributes).to include("langfuse.observation.type" => "agent", "langfuse.trace.input" => "Report the newest email".to_json,
                                       "langfuse.trace.output" => "Newest email: Chris".to_json, "langfuse.trace.name" => "Inbox · session #{session.id}")
    expect(turn.attributes).to include("langfuse.trace.input" => "Report the newest email".to_json, # before the session ends
                                       "langfuse.trace.metadata.agent_session_id" => session.id.to_s, # findable while it runs
                                       "langfuse.trace.metadata.agent_computer_id" => computer.id.to_s,
                                       "langfuse.trace.metadata.canine_url" => end_with("/agent_computers/#{computer.id}/sessions/#{session.id}"))
  end

  it "shows a reply's reasoning as thinking, so the model's plan is visible" do
    call = { "id" => "1", "type" => "function", "function" => { "name" => "computer_windows", "arguments" => "{}" } }
    expect(described_class.reply("role" => "assistant", "content" => nil, "reasoning" => "Open the page first", "tool_calls" => [ call ],
                                 "reasoning_details" => [ { "type" => "reasoning.text", "text" => "Open the page first" } ])).to eq(
      role: "assistant", content: "", thinking: [ { type: "thinking", content: "Open the page first" } ], tool_calls: [ call ]
    )
    expect(described_class.reply("role" => "assistant", "content" => "Done", "reasoning_details" => [ { "type" => "reasoning.summary", "summary" => "Plan" } ]))
      .to eq(role: "assistant", content: "Done", thinking: [ { type: "thinking", content: "Plan" } ])
  end

  it "shows a model call that failed, and the turn it failed, as errors" do
    stub_const("ENV", ENV.to_h.merge("LANGFUSE_HOST" => "http://localhost:3100", "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk"))
    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)
    expect do
      described_class.session(session, "turn 1") { Llm::OpenRouter.new("key").chat(model: "test/model", messages: [ { role: "user", content: "Start now." } ]) }
    end.to raise_error(Llm::OpenRouter::Error, /Couldn't reach OpenRouter/)

    chat, turn = pushed
    expect(chat).to have_attributes(name: "openrouter chat", parent_id: turn.span_id)
    expect([ chat.error, turn.error ]).to all(be_a(Llm::OpenRouter::Error))
    expect(chat.attributes).to include("langfuse.observation.type" => "generation", "langfuse.observation.model.name" => "test/model")
  end

  it "does nothing unless Langfuse is configured" do
    stub_const("ENV", ENV.to_h.except("LANGFUSE_HOST"))
    result = described_class.session(session, "turn 1") do
      described_class.span("x") { |traced| traced.output = "y" }
      :ran
    end
    expect(result).to eq(:ran)
    expect(pushed).to be_empty
  end
end
