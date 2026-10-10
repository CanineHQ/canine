require "rails_helper"

RSpec.describe AgentLoop::Wrapup do
  it "asks for a summary when a session stops without one, and falls back to its notes" do
    account_user = create(:account_user)
    computer = AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running)
    account_user.account.agent_provider_keys.create!(api_key: "sk-or-test")
    session = computer.agent_sessions.create!(trigger: :manual, model: "test/model", status: :failed, error: "Stopped after 5 minutes.",
                                              notes: "Found: the newest email is from Chris.")
    session.messages.create!(position: 0, role: "system", content: "You are an agent")
    client = instance_double(Llm::OpenRouter)
    allow(Llm::OpenRouter).to receive(:new).and_return(client)
    finish = { "id" => "c1", "type" => "function", "function" => { "name" => "finish", "arguments" => { summary: "Newest email: Chris." }.to_json } }
    allow(client).to receive(:chat).and_return(Llm::OpenRouter::Reply.new({ "tool_calls" => [ finish ] }, { cost_usd: 0.001 }))

    described_class.call(session)
    expect(session.reload.summary).to start_with("Newest email: Chris.").and include("Stopped after 5 minutes.")

    session.update!(summary: nil)
    allow(client).to receive(:chat).and_raise(Llm::OpenRouter::Error, "down")
    described_class.call(session)
    expect(session.reload.summary).to include("Found: the newest email is from Chris.")
  end
end
