require "rails_helper"

RSpec.describe AgentLoop::Context do
  let(:account_user) { create(:account_user) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running) }
  let(:session) { computer.agent_sessions.create!(trigger: :manual, model: "test/model", status: :running) }

  it "shortens old results and their calls' arguments in blocks, and caps recent ones" do
    position = 0
    add = ->(**attrs) { session.messages.create!(position: position += 1, **attrs) }
    13.times do |i|
      script = { command: "cat > notes.md <<'EOF'\n#{"line\n" * 100}EOF" }.to_json
      add.(role: "assistant", tool_calls: [ { "id" => "c#{i}", "type" => "function", "function" => { "name" => "computer_run", "arguments" => script } } ])
      add.(role: "tool", tool_call_id: "c#{i}", content: (i == 12 ? "y" : "x") * 20_000)
    end

    sent = described_class.messages(session)
    results = sent.select { |m| m[:role] == "tool" }.map { |m| m[:content] }
    expect(results.first(8)).to all(start_with("x" * 300).and(include("shortened from 20000")))     # one block of 8
    expect(results[8]).to start_with("x" * 4000)                                                     # 9-13 still whole...
    expect(results.last).to start_with("y" * 4000).and include("shortened")                          # ...capped at 4,000
    expect(results.last.length).to be < 4100
    first_call = JSON.parse(sent.find { |m| m[:role] == "assistant" }[:tool_calls].first.dig("function", "arguments"))
    expect(first_call["command"]).to end_with("…").and(satisfy { |c| c.length <= 201 })
  end
end
