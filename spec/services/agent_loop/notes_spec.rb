require "rails_helper"

RSpec.describe AgentLoop::Notes do
  it "folds the oldest turns into notes once there are enough, and sends the notes instead of them" do
    account_user = create(:account_user)
    computer = AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running)
    session = computer.agent_sessions.create!(trigger: :manual, model: "test/model", status: :running)
    session.messages.create!(position: 0, role: "system", content: "You are an agent")
    session.messages.create!(position: 1, role: "user", content: "Start now")
    41.times do |turn|
      call = { "id" => "c#{turn}", "type" => "function", "function" => { "name" => "computer_run", "arguments" => "{}" } }
      session.messages.create!(position: 2 + turn * 2, role: "assistant", content: "turn #{turn}", tool_calls: [ call ])
      session.messages.create!(position: 3 + turn * 2, role: "tool", tool_call_id: "c#{turn}", content: "ok")
    end
    client = instance_double(Llm::OpenRouter)
    allow(Llm::OpenRouter).to receive(:new).and_return(client)
    allow(client).to receive(:chat).and_return(Llm::OpenRouter::Reply.new({ "content" => "Done: checked Slack" }, { input_tokens: 10, output_tokens: 5, cost_usd: 0.001 }))

    expect(described_class.fold(session, "sk-or-test")).to be true
    expect(described_class.fold(session, "sk-or-test")).to be false # nothing more to fold yet

    sent = AgentLoop::Context.messages(session)
    expect(sent.first(3).map { |m| m[:content] }).to match([ "You are an agent", "Start now", include("Done: checked Slack") ])
    expect(sent[3]).to include(role: "assistant", content: "turn 21") # a whole turn: its call and result stay together
    expect(sent.count { |m| m[:role] == "assistant" }).to eq(20)
  end
end
